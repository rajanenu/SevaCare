package com.sevacare.pharmacy.billing.service;

import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.billing.spi.PaymentMode;
import com.sevacare.pharmacy.billing.spi.BillingEvents;
import com.sevacare.pharmacy.billing.spi.SaleReceipt;
import com.sevacare.pharmacy.capability.spi.CapabilityPolicies;
import com.sevacare.pharmacy.capability.spi.PolicyKey;
import com.sevacare.pharmacy.capability.spi.PolicyMode;
import com.sevacare.pharmacy.catalog.spi.CatalogLookup;
import com.sevacare.pharmacy.catalog.spi.SkuSummary;
import com.sevacare.pharmacy.inventory.spi.BatchAllocation;
import com.sevacare.pharmacy.inventory.spi.BatchInfo;
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.StockLedger;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.shared.event.DomainEvent;
import com.sevacare.shared.event.EventPublisher;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The counter sale — the twenty-second transaction the whole product is built to
 * make fast. One method, one transaction: it prices each line at the batch's
 * printed MRP, backs the GST out of that MRP, draws the stock through the ledger,
 * and writes the bill. The sale document and the stock movement commit together
 * or not at all, so a receipt without a dispense, or a dispense without a bill,
 * cannot exist.
 *
 * <p>What it will <em>not</em> do is decide policy silently. Whether a Schedule H
 * item may leave without a prescriber, whether stock may go negative, whether an
 * expired batch may be dispensed — those are {@link CapabilityPolicies} knobs, and
 * at the default SUGGEST the sale completes with a warning on the receipt rather
 * than a refusal, because an Indian counter that stops for every amber flag stops.
 */
@Service
public class CounterSaleService {

    private static final Logger log = LoggerFactory.getLogger(CounterSaleService.class);

    private final JdbcTemplate jdbcTemplate;
    private final CatalogLookup catalog;
    private final StockLedger stockLedger;
    private final CapabilityPolicies policies;
    private final EventPublisher eventPublisher;
    private final PharmacyReceiptNotifier receiptNotifier;

    public CounterSaleService(JdbcTemplate jdbcTemplate,
                              CatalogLookup catalog,
                              StockLedger stockLedger,
                              CapabilityPolicies policies,
                              EventPublisher eventPublisher,
                              PharmacyReceiptNotifier receiptNotifier) {
        this.jdbcTemplate = jdbcTemplate;
        this.catalog = catalog;
        this.stockLedger = stockLedger;
        this.policies = policies;
        this.eventPublisher = eventPublisher;
        this.receiptNotifier = receiptNotifier;
    }

    @Transactional
    public SaleReceipt sell(CreateSaleCommand command) {
        if (command.lines() == null || command.lines().isEmpty()) {
            throw new IllegalArgumentException("A sale needs at least one line");
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());
        String location = stockLedger.defaultLocationId();

        boolean enforceNoNegative = policies.modeOf(PolicyKey.NEGATIVE_STOCK).isEnforced();
        boolean enforceRx = policies.modeOf(PolicyKey.RX_REQUIRED_FOR_SCHEDULE_H).isEnforced();
        boolean priceEditAllowed = policies.modeOf(PolicyKey.PRICE_EDIT_AT_BILLING) != PolicyMode.OFF;
        LocalDate today = LocalDate.now();

        long number = nextSaleNumber(schema);
        String salePublicId = "SAL-" + String.format("%06d", number);
        String invoiceNo = "INV-" + String.format("%06d", number);

        List<String> warnings = new ArrayList<>();
        List<PricedLine> priced = new ArrayList<>();
        List<StockMovement> movements = new ArrayList<>();

        for (CreateSaleCommand.LineRequest req : command.lines()) {
            if (req.qtyBaseUnits() <= 0) {
                throw new IllegalArgumentException("A sale line needs a positive quantity");
            }

            if (req.isManual()) {
                if (isBlank(req.manualLabel()) || req.manualAmountPaise() == null || req.manualAmountPaise() < 0) {
                    throw new IllegalArgumentException("A manual line needs a label and a non-negative amount");
                }
                long gross = req.manualAmountPaise();
                long discount = req.discountPaise() == null ? 0 : Math.min(Math.max(0, req.discountPaise()), gross);
                long taxable = gross - discount;
                // Not a medicine: no GST breakdown, no batch, no stock movement — just
                // an amount the pharmacist typed in and the customer paid.
                priced.add(new PricedLine(null, new Alloc(null, req.qtyBaseUnits(), null, req.manualAmountPaise()),
                        gross, discount, taxable, 0, req.manualLabel()));
                continue;
            }

            SkuSummary sku = catalog.findSku(req.skuPublicId())
                    .orElseThrow(() -> new IllegalArgumentException("Unknown SKU: " + req.skuPublicId()));

            if (sku.isPrescriptionOnly() && isBlank(command.prescriberName())) {
                String msg = sku.brandName() + " is a Schedule " + sku.scheduleClass()
                        + " medicine and needs a prescriber recorded on the bill.";
                if (enforceRx) {
                    throw new IllegalStateException(msg);
                }
                warnings.add(msg + " Sold without one.");
            }

            Long override = priceEditAllowed ? req.mrpOverridePaise() : null;
            if (!priceEditAllowed && req.mrpOverridePaise() != null) {
                warnings.add("Price edit is off for this pharmacy; " + sku.brandName()
                        + " was billed at its printed MRP.");
            }

            List<Alloc> allocs = resolveAllocations(sku, req, location, today, enforceNoNegative, override, warnings);

            long lineGross = allocs.stream().mapToLong(a -> a.mrpPaise() * a.qty()).sum();
            long lineDiscount = req.discountPaise() == null ? 0 : Math.max(0, req.discountPaise());
            if (lineDiscount > lineGross) {
                lineDiscount = lineGross;
            }

            // Discount is prorated across the batches a line drew from, so each
            // sale_line carries its own share and the batch-level totals still sum.
            long discountLeft = lineDiscount;
            for (int i = 0; i < allocs.size(); i++) {
                Alloc a = allocs.get(i);
                long gross = a.mrpPaise() * (long) a.qty();
                long discount = (i == allocs.size() - 1)
                        ? discountLeft
                        : (lineGross == 0 ? 0 : lineDiscount * gross / lineGross);
                discountLeft -= discount;
                long net = gross - discount;
                long taxable = taxableFromInclusive(net, sku.gstRateBp());
                long gst = net - taxable;

                priced.add(new PricedLine(sku, a, gross, discount, taxable, gst, null));
                movements.add(StockMovement.of(
                        sku.skuPublicId(), a.batchPublicId(), location, -a.qty(),
                        MovementReason.SALE, "SALE", salePublicId, command.actor()));
            }
        }

        long gross = priced.stream().mapToLong(PricedLine::gross).sum();
        long discount = priced.stream().mapToLong(PricedLine::discount).sum();
        long taxable = priced.stream().mapToLong(PricedLine::taxable).sum();
        long gst = priced.stream().mapToLong(PricedLine::gst).sum();
        long total = gross - discount;

        PaymentMode payment = command.paymentMode() == null ? PaymentMode.CASH : command.paymentMode();
        Instant soldAt = Instant.now();

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".sale " +
                "(sale_public_id, tenant_public_id, invoice_no, location_id, sale_date, sold_at, " +
                " customer_name, customer_mobile, prescriber_name, payment_mode, " +
                " gross_paise, discount_paise, taxable_paise, gst_paise, total_paise, actor, note) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                salePublicId, tenantPublicId, invoiceNo, location, java.sql.Date.valueOf(today),
                Timestamp.from(soldAt), trimToNull(command.customerName()), trimToNull(command.customerMobile()),
                trimToNull(command.prescriberName()), payment.name(),
                gross, discount, taxable, gst, total, command.actor(), trimToNull(command.note()));

        for (PricedLine pl : priced) {
            jdbcTemplate.update(
                    "INSERT INTO " + schema + ".sale_line " +
                    "(sale_public_id, sku_public_id, batch_public_id, schedule_class, qty_base_units, " +
                    " mrp_paise, gross_paise, discount_paise, gst_rate_bp, taxable_paise, gst_paise, manual_label) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    salePublicId,
                    pl.sku() == null ? null : pl.sku().skuPublicId(),
                    pl.alloc().batchPublicId(),
                    pl.sku() == null ? null : pl.sku().scheduleClass(),
                    pl.alloc().qty(), pl.alloc().mrpPaise(), pl.gross(), pl.discount(),
                    pl.sku() == null ? 0 : pl.sku().gstRateBp(), pl.taxable(), pl.gst(),
                    pl.manualLabel());
        }

        // One append for the whole sale: canonical lock order, so two sales sharing
        // batches cannot deadlock, and the balance moves in the same transaction as
        // the bill that caused it.
        stockLedger.appendAll(movements);

        announce(salePublicId, invoiceNo, payment, gross, total, gst, command.actor());
        log.info("pharmacy_sale_completed sale={} invoice={} lines={} total_paise={}",
                salePublicId, invoiceNo, priced.size(), total);

        List<SaleReceipt.Line> receiptLines = new ArrayList<>();
        for (PricedLine pl : priced) {
            boolean manual = pl.sku() == null;
            receiptLines.add(new SaleReceipt.Line(
                    manual ? null : pl.sku().skuPublicId(),
                    manual ? pl.manualLabel() : pl.sku().brandName(),
                    pl.alloc().batchPublicId(),
                    pl.alloc().expiryDate(),
                    manual ? null : pl.sku().scheduleClass(),
                    pl.alloc().qty(), pl.alloc().mrpPaise(), pl.gross(), pl.discount(),
                    manual ? 0 : pl.sku().gstRateBp(),
                    pl.taxable(), pl.gst()));
        }
        SaleReceipt receipt = new SaleReceipt(
                salePublicId, invoiceNo, today, soldAt,
                trimToNull(command.customerName()), trimToNull(command.customerMobile()),
                trimToNull(command.prescriberName()), payment,
                gross, discount, taxable, gst, total, receiptLines, List.copyOf(warnings), null);

        String waLink = receiptNotifier.notify(tenantPublicId, receipt);
        return waLink == null ? receipt : new SaleReceipt(
                receipt.salePublicId(), receipt.invoiceNo(), receipt.saleDate(), receipt.soldAt(),
                receipt.customerName(), receipt.customerMobile(), receipt.prescriberName(), receipt.paymentMode(),
                receipt.grossPaise(), receipt.discountPaise(), receipt.taxablePaise(), receipt.gstPaise(),
                receipt.totalPaise(), receipt.lines(), receipt.warnings(), waLink);
    }

    /**
     * Voids a completed sale — the "delete" the invoice table offers. The
     * ledger is append-only, so nothing here is edited: every stock_ledger row
     * this sale caused ({@code ref_type='SALE'}) gets a compensating entry via
     * {@link StockLedger#reverse}, and the sale itself flips to {@code VOID}
     * (a status the schema already reserves for exactly this). A manual
     * (non-catalog) line left no ledger row to reverse, so it's simply skipped.
     */
    @Transactional
    public void voidSale(String salePublicId, String actor) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        List<String> status = jdbcTemplate.queryForList(
                "SELECT status FROM " + schema + ".sale WHERE sale_public_id = ?", String.class, salePublicId);
        if (status.isEmpty()) {
            throw new IllegalArgumentException("Unknown sale: " + salePublicId);
        }
        if ("VOID".equals(status.get(0))) {
            throw new IllegalStateException("Sale " + salePublicId + " is already void.");
        }

        List<Long> ledgerIds = jdbcTemplate.queryForList(
                "SELECT ledger_id FROM " + schema + ".stock_ledger WHERE ref_type = 'SALE' AND ref_id = ?",
                Long.class, salePublicId);
        for (Long ledgerId : ledgerIds) {
            stockLedger.reverse(ledgerId, actor, "Sale " + salePublicId + " voided");
        }

        jdbcTemplate.update(
                "UPDATE " + schema + ".sale SET status = 'VOID' WHERE sale_public_id = ?", salePublicId);
        log.info("pharmacy_sale_voided sale={} actor={} ledger_reversals={}",
                salePublicId, actor, ledgerIds.size());
    }

    private List<Alloc> resolveAllocations(SkuSummary sku, CreateSaleCommand.LineRequest req, String location,
                                           LocalDate today, boolean enforceNoNegative, Long override,
                                           List<String> warnings) {
        List<Alloc> allocs = new ArrayList<>();

        if (!isBlank(req.batchPublicId())) {
            BatchInfo batch = stockLedger.findBatch(req.batchPublicId())
                    .orElseThrow(() -> new IllegalArgumentException("Unknown batch: " + req.batchPublicId()));
            if (!batch.skuPublicId().equals(sku.skuPublicId())) {
                throw new IllegalArgumentException(
                        "Batch " + batch.batchPublicId() + " does not belong to " + sku.brandName());
            }
            // EXPIRED_BATCH_DISPENSE has no OFF: an expired or recalled batch is
            // refused regardless of any other setting.
            if (!batch.isDispensable(today)) {
                throw new IllegalStateException(
                        "Batch " + batch.batchPublicId() + " of " + sku.brandName()
                        + " cannot be dispensed (" + batch.batchStatus().toLowerCase() + ").");
            }
            long mrp = override != null ? override : batch.mrpPaise();
            allocs.add(new Alloc(batch.batchPublicId(), req.qtyBaseUnits(), batch.expiryDate(), mrp));
            return allocs;
        }

        BatchAllocation.Result result = stockLedger.allocateFefo(sku.skuPublicId(), location, req.qtyBaseUnits());
        for (BatchAllocation a : result.allocations()) {
            allocs.add(new Alloc(a.batchPublicId(), a.qtyBaseUnits(), a.expiryDate(),
                    override != null ? override : a.mrpPaise()));
        }

        if (result.shortfallBaseUnits() > 0) {
            if (allocs.isEmpty()) {
                throw new IllegalStateException(
                        "No stock of " + sku.brandName() + " has been received yet. Receive stock before selling it.");
            }
            if (enforceNoNegative) {
                throw new IllegalStateException(
                        "Only " + result.allocatedBaseUnits() + " " + sku.baseUnit().name().toLowerCase()
                        + " of " + sku.brandName() + " in stock; asked for " + req.qtyBaseUnits() + ".");
            }
            // Negative stock is information, not corruption: the remainder goes onto
            // the earliest batch and raises a reconciliation flag, so the customer
            // is served and the missing GRN surfaces.
            Alloc first = allocs.get(0);
            allocs.set(0, new Alloc(first.batchPublicId(), first.qty() + result.shortfallBaseUnits(),
                    first.expiryDate(), first.mrpPaise()));
            warnings.add("Sold " + result.shortfallBaseUnits() + " " + sku.baseUnit().name().toLowerCase()
                    + " of " + sku.brandName() + " beyond recorded stock — reconcile the batch.");
        }
        return allocs;
    }

    private void announce(String salePublicId, String invoiceNo, PaymentMode payment,
                          long gross, long total, long gst, String actor) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("salePublicId", salePublicId);
        payload.put("invoiceNo", invoiceNo);
        payload.put("paymentMode", payment.name());
        payload.put("grossPaise", gross);
        payload.put("totalPaise", total);
        payload.put("gstPaise", gst);
        eventPublisher.publish(DomainEvent
                .of(BillingEvents.SALE_COMPLETED, "Sale", salePublicId, payload)
                .withActor(actor));
    }

    /**
     * Backs the GST-exclusive value out of a GST-inclusive amount. Indian retail
     * MRP is tax-inclusive, so a ₹105 sale at 5% is ₹100 taxable + ₹5 GST, not
     * ₹105 + ₹5.25. Integer rounding to the nearest paisa; GST is then the
     * remainder, so taxable + gst reconstructs the amount charged exactly.
     */
    public static long taxableFromInclusive(long inclusivePaise, int gstRateBp) {
        long denominator = 10_000L + gstRateBp;
        return (inclusivePaise * 10_000L + denominator / 2) / denominator;
    }

    private long nextSaleNumber(String schema) {
        Long value = jdbcTemplate.queryForObject(
                "SELECT nextval('" + schema + ".sale_public_id_seq')", Long.class);
        if (value == null) {
            throw new IllegalStateException("Could not generate a sale number");
        }
        return value;
    }

    private static boolean isBlank(String s) {
        return s == null || s.isBlank();
    }

    private static String trimToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    /** {@code batchPublicId} is null for a manual (non-catalog) line. */
    private record Alloc(String batchPublicId, int qty, LocalDate expiryDate, long mrpPaise) {
    }

    /** {@code sku} and {@code manualLabel} are mutually exclusive — exactly one is set. */
    private record PricedLine(SkuSummary sku, Alloc alloc, long gross, long discount, long taxable, long gst,
                              String manualLabel) {
    }
}
