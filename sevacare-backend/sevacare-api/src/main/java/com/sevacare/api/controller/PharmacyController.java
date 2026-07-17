package com.sevacare.api.controller;

import java.security.Principal;
import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.sevacare.pharmacy.billing.service.CounterSaleService;
import com.sevacare.pharmacy.billing.service.CreateSaleCommand;
import com.sevacare.pharmacy.billing.service.CreditService;
import com.sevacare.pharmacy.billing.service.DayCloseService;
import com.sevacare.pharmacy.billing.service.SaleQueryService;
import com.sevacare.pharmacy.billing.spi.CreditOutstanding;
import com.sevacare.pharmacy.billing.spi.CustomerHistoryPage;
import com.sevacare.pharmacy.billing.spi.DailyTotal;
import com.sevacare.pharmacy.billing.spi.DaySummary;
import com.sevacare.pharmacy.billing.spi.GstSlabTotal;
import com.sevacare.pharmacy.billing.spi.MoneyView;
import com.sevacare.pharmacy.billing.spi.PaymentMode;
import com.sevacare.pharmacy.billing.spi.SaleReceipt;
import com.sevacare.pharmacy.billing.spi.SalesRegisterLine;
import com.sevacare.pharmacy.billing.spi.SaleSummary;
import com.sevacare.pharmacy.billing.spi.TopMedicine;
import com.sevacare.pharmacy.catalog.service.CatalogService;
import com.sevacare.pharmacy.catalog.service.CreateSkuCommand;
import com.sevacare.pharmacy.catalog.spi.BaseUnit;
import com.sevacare.pharmacy.catalog.spi.CounterSku;
import com.sevacare.pharmacy.catalog.spi.SkuSummary;
import com.sevacare.pharmacy.inventory.service.CreateBatchCommand;
import com.sevacare.pharmacy.inventory.service.InventoryService;
import com.sevacare.pharmacy.inventory.spi.GrnReceipt;
import com.sevacare.pharmacy.inventory.spi.LowStockItem;
import com.sevacare.pharmacy.inventory.spi.NearExpiryBatch;
import com.sevacare.pharmacy.procurement.service.GrnService;
import com.sevacare.pharmacy.procurement.service.PostGrnCommand;
import com.sevacare.pharmacy.procurement.service.SupplierService;
import com.sevacare.pharmacy.procurement.spi.GrnSummary;
import com.sevacare.pharmacy.procurement.spi.PostedGrn;
import com.sevacare.pharmacy.procurement.spi.SupplierInfo;
import com.sevacare.pharmacy.returns.service.CustomerReturnService;
import com.sevacare.pharmacy.returns.service.PostReturnCommand;
import com.sevacare.pharmacy.returns.spi.PostedReturn;
import com.sevacare.pharmacy.returns.spi.RecentReturn;
import com.sevacare.pharmacy.returns.spi.ReturnableLine;
import com.sevacare.api.service.IdempotencyService;
import com.sevacare.shared.dto.ContractResponse;
import com.sevacare.shared.dto.PharmacyDtos;
import com.sevacare.shared.tenant.TenantContext;

import jakarta.validation.Valid;

/**
 * The pharmacy counter's API. Everything under {@code /api/v1/pharmacy} is behind
 * {@code ModuleAccessFilter}: a tenant without a pharmacy sees 404 here, not 403,
 * so the endpoints simply do not exist for a hospital that never bought the module.
 *
 * <p>Operators are the tenant's ADMIN (the owner) and STAFF (the pharmacist at the
 * counter). The clinical roles are intentionally absent — a doctor does not ring up
 * a sale, and a standalone store has no doctors at all.
 */
@RestController
@RequestMapping("/api/v1/pharmacy")
@PreAuthorize("hasAnyRole('ADMIN','STAFF')")
public class PharmacyController {

    private final CatalogService catalogService;
    private final InventoryService inventoryService;
    private final CounterSaleService counterSaleService;
    private final SaleQueryService saleQueryService;
    private final SupplierService supplierService;
    private final GrnService grnService;
    private final CustomerReturnService customerReturnService;
    private final DayCloseService dayCloseService;
    private final CreditService creditService;
    private final IdempotencyService idempotencyService;

    public PharmacyController(CatalogService catalogService,
                             InventoryService inventoryService,
                             CounterSaleService counterSaleService,
                             SaleQueryService saleQueryService,
                             SupplierService supplierService,
                             GrnService grnService,
                             CustomerReturnService customerReturnService,
                             DayCloseService dayCloseService,
                             CreditService creditService,
                             IdempotencyService idempotencyService) {
        this.catalogService = catalogService;
        this.inventoryService = inventoryService;
        this.counterSaleService = counterSaleService;
        this.saleQueryService = saleQueryService;
        this.supplierService = supplierService;
        this.grnService = grnService;
        this.customerReturnService = customerReturnService;
        this.dayCloseService = dayCloseService;
        this.creditService = creditService;
        this.idempotencyService = idempotencyService;
    }

    // ---- Catalog --------------------------------------------------------

    @GetMapping("/{tenantPublicId}/catalog/search")
    public ContractResponse<List<CounterSku>> search(@PathVariable String tenantPublicId,
                                                     @RequestParam("q") String query,
                                                     @RequestParam(value = "limit", defaultValue = "15") int limit) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(catalogService.searchForCounter(query, limit));
    }

    /**
     * The whole active catalog with live on-hand and MRP, for the counter to hold
     * and search offline.
     *
     * <p>Tagged with the store's catalog-and-stock version. A counter that already
     * holds that version sends it back as {@code If-None-Match} and gets a 304 — so
     * reopening the till costs one small query and no payload, while a sale a colleague
     * rang up on another device changes the tag and pulls the new shelf down at once.
     * Freshness is decided by the data, not a timer, which is what makes it correct
     * when Cloud Run is running more than one instance of us.
     */
    @GetMapping("/{tenantPublicId}/catalog/stock")
    public ResponseEntity<ContractResponse<List<CounterSku>>> catalogStock(
            @PathVariable String tenantPublicId,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch) {
        requireTenant(tenantPublicId);
        CatalogService.CounterCatalog catalog = catalogService.counterCatalog();
        String etag = "\"" + catalog.version() + "\"";

        if (etag.equals(ifNoneMatch)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
        }
        return ResponseEntity.ok().eTag(etag).body(ContractResponse.of(catalog.items()));
    }

    /** Import a supplier's catalog (and optionally its opening stock) in one pass. */
    @PostMapping("/{tenantPublicId}/catalog/import")
    public ContractResponse<CatalogService.ImportOutcome> importCatalog(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody PharmacyDtos.CatalogImportRequest request,
            Principal principal) {
        requireTenant(tenantPublicId);
        List<CatalogService.ImportRow> rows = request.rows().stream()
                .map(r -> new CatalogService.ImportRow(
                        r.brandName(), r.manufacturer(), r.dosageForm(), r.strength(), r.baseUnit(),
                        r.scheduleClass(), r.hsnCode(), r.gstRateBp(), r.rackLocation(), r.reorderLevel(),
                        r.batchNo(), r.expiryDate(), r.mrpPaise(), r.purchasePricePaise(), r.openingQty()))
                .collect(Collectors.toList());
        CatalogService.StockIntake intake =
                (skuId, batchNo, expiry, mrpPaise, purchasePricePaise, qty, actor) ->
                        inventoryService.receiveStock(
                                new CreateBatchCommand(skuId, batchNo, expiry, mrpPaise, purchasePricePaise, null),
                                qty, actor);
        return ContractResponse.of(
                catalogService.bulkImport(rows, intake, actorOf(principal)));
    }

    // ---- Analytics ------------------------------------------------------

    /**
     * Top-selling medicines over a window, for the reorder decision. {@code period}
     * is DAY, WEEK, MONTH or YEAR (ending today); anything else falls back to WEEK.
     */
    @GetMapping("/{tenantPublicId}/analytics/top-medicines")
    public ContractResponse<List<TopMedicine>> topMedicines(
            @PathVariable String tenantPublicId,
            @RequestParam(value = "period", defaultValue = "WEEK") String period,
            @RequestParam(value = "limit", defaultValue = "15") int limit) {
        requireTenant(tenantPublicId);
        LocalDate today = LocalDate.now();
        LocalDate from = switch (period == null ? "" : period.toUpperCase()) {
            case "DAY" -> today;
            case "MONTH" -> today.minusDays(29);
            case "YEAR" -> today.minusDays(364);
            default -> today.minusDays(6);
        };
        return ContractResponse.of(saleQueryService.topMedicines(from, today, limit));
    }

    @PostMapping("/{tenantPublicId}/catalog/skus")
    public ContractResponse<SkuSummary> createSku(@PathVariable String tenantPublicId,
                                                  @Valid @RequestBody PharmacyDtos.QuickSkuRequest request) {
        requireTenant(tenantPublicId);
        List<CreateSkuCommand.PackLevel> packs = request.packs() == null ? List.of()
                : request.packs().stream()
                        .map(p -> new CreateSkuCommand.PackLevel(p.packName(), p.unitsInPack(), p.sellableOrDefault()))
                        .collect(Collectors.toList());
        CreateSkuCommand command = new CreateSkuCommand(
                request.brandName(), request.manufacturer(), request.dosageForm(), request.strength(),
                BaseUnit.parse(request.baseUnit()), request.scheduleClass(), request.hsnCode(),
                request.gstRateBp(), request.rackLocation(), request.reorderLevel(), request.reorderQty(),
                null, packs, request.aliases());
        return ContractResponse.of(catalogService.createSku(command));
    }

    // ---- Inventory ------------------------------------------------------

    @PostMapping("/{tenantPublicId}/stock/receive")
    public ContractResponse<GrnReceipt> receiveStock(@PathVariable String tenantPublicId,
                                                     @Valid @RequestBody PharmacyDtos.ReceiveStockRequest request,
                                                     Principal principal) {
        requireTenant(tenantPublicId);
        CreateBatchCommand batch = new CreateBatchCommand(
                request.skuPublicId(), request.batchNo(), request.expiryDate(),
                request.mrpPaise(), request.purchasePricePaise(), request.supplierPublicId());
        return ContractResponse.of(
                inventoryService.receiveStock(batch, request.qtyBaseUnits(), actorOf(principal)));
    }

    @GetMapping("/{tenantPublicId}/inventory/near-expiry")
    public ContractResponse<List<NearExpiryBatch>> nearExpiry(@PathVariable String tenantPublicId) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(inventoryService.nearExpiryBatches());
    }

    @GetMapping("/{tenantPublicId}/inventory/low-stock")
    public ContractResponse<List<LowStockItem>> lowStock(@PathVariable String tenantPublicId) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(inventoryService.lowStockItems());
    }

    // ---- Sales ----------------------------------------------------------

    @PostMapping("/{tenantPublicId}/sales")
    public ContractResponse<SaleReceipt> sell(@PathVariable String tenantPublicId,
                                              @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
                                              @Valid @RequestBody PharmacyDtos.SaleRequest request,
                                              Principal principal) {
        requireTenant(tenantPublicId);
        List<CreateSaleCommand.LineRequest> lines = request.lines().stream()
                .map(l -> new CreateSaleCommand.LineRequest(
                        l.skuPublicId(), l.qtyBaseUnits(), l.batchPublicId(), l.discountPaise(), l.mrpOverridePaise(),
                        l.manualLabel(), l.manualAmountPaise()))
                .collect(Collectors.toList());
        CreateSaleCommand command = new CreateSaleCommand(
                request.customerName(), request.customerMobile(), request.prescriberName(),
                PaymentMode.parse(request.paymentMode()), actorOf(principal), request.note(), lines);
        // A sale retried on a flaky network must not dispense twice: the ledger
        // would faithfully record both. The retry replays the first receipt.
        return ContractResponse.of(idempotencyService.execute(
                tenantPublicId, idempotencyKey, "counter-sale", SaleReceipt.class,
                () -> counterSaleService.sell(command)));
    }

    @GetMapping("/{tenantPublicId}/sales/recent")
    public ContractResponse<List<SaleSummary>> recentSales(@PathVariable String tenantPublicId,
                                                           @RequestParam(value = "limit", defaultValue = "20") int limit) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.recentSales(limit));
    }

    @GetMapping("/{tenantPublicId}/sales/day-summary")
    public ContractResponse<DaySummary> daySummary(
            @PathVariable String tenantPublicId,
            @RequestParam(value = "date", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.daySummary(date == null ? LocalDate.now() : date));
    }

    @GetMapping("/{tenantPublicId}/sales/{salePublicId}")
    public ResponseEntity<ContractResponse<SaleReceipt>> receipt(@PathVariable String tenantPublicId,
                                                                 @PathVariable String salePublicId) {
        requireTenant(tenantPublicId);
        return saleQueryService.findReceipt(salePublicId)
                .map(r -> ResponseEntity.ok(ContractResponse.of(r)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /** The line-level audit trail for a date range — the downloadable sales/audit register. */
    @GetMapping("/{tenantPublicId}/reports/sales-register")
    public ContractResponse<List<SalesRegisterLine>> salesRegister(
            @PathVariable String tenantPublicId,
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.salesRegister(from, to));
    }

    // ---- Suppliers & GRN --------------------------------------------------

    @GetMapping("/{tenantPublicId}/suppliers")
    public ContractResponse<List<SupplierInfo>> suppliers(@PathVariable String tenantPublicId) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(supplierService.listActive());
    }

    @PostMapping("/{tenantPublicId}/suppliers")
    public ContractResponse<SupplierInfo> createSupplier(@PathVariable String tenantPublicId,
                                                         @Valid @RequestBody PharmacyDtos.SupplierRequest request) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(supplierService.createOrGet(
                request.supplierName(), request.mobileNumber(), request.email(), request.gstin(),
                request.city(), request.returnWindowDays()));
    }

    @PostMapping("/{tenantPublicId}/grn")
    public ContractResponse<PostedGrn> postGrn(@PathVariable String tenantPublicId,
                                               @Valid @RequestBody PharmacyDtos.GrnRequest request,
                                               Principal principal) {
        requireTenant(tenantPublicId);
        List<PostGrnCommand.LineRequest> lines = request.lines().stream()
                .map(l -> new PostGrnCommand.LineRequest(
                        l.skuPublicId(), l.batchNo(), l.expiryDate(), l.qtyBaseUnits(),
                        l.freeQtyBaseUnits(), l.mrpPaise(), l.purchasePricePaise()))
                .collect(Collectors.toList());
        return ContractResponse.of(grnService.post(new PostGrnCommand(
                request.supplierPublicId(), request.supplierInvoiceNo(), request.invoiceDate(),
                request.note(), actorOf(principal), lines)));
    }

    @GetMapping("/{tenantPublicId}/grn/recent")
    public ContractResponse<List<GrnSummary>> recentGrns(@PathVariable String tenantPublicId,
                                                         @RequestParam(value = "limit", defaultValue = "20") int limit) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(grnService.recentGrns(limit));
    }

    // ---- Customer returns -------------------------------------------------

    @GetMapping("/{tenantPublicId}/sales/{salePublicId}/returnable")
    public ContractResponse<List<ReturnableLine>> returnableLines(@PathVariable String tenantPublicId,
                                                                  @PathVariable String salePublicId) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(customerReturnService.returnableLines(salePublicId));
    }

    @PostMapping("/{tenantPublicId}/returns")
    public ContractResponse<PostedReturn> postReturn(@PathVariable String tenantPublicId,
                                                     @Valid @RequestBody PharmacyDtos.ReturnRequest request,
                                                     Principal principal) {
        requireTenant(tenantPublicId);
        List<PostReturnCommand.LineRequest> lines = request.lines().stream()
                .map(l -> new PostReturnCommand.LineRequest(
                        l.skuPublicId(), l.batchPublicId(), l.qtyBaseUnits(), l.disposition()))
                .collect(Collectors.toList());
        return ContractResponse.of(customerReturnService.post(new PostReturnCommand(
                request.salePublicId(), request.refundMode(), request.reason(),
                actorOf(principal), lines)));
    }

    // ---- Credit ledger (khata) ---------------------------------------------

    @GetMapping("/{tenantPublicId}/credit/outstanding")
    public ContractResponse<List<CreditOutstanding>> creditOutstanding(@PathVariable String tenantPublicId) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(creditService.outstanding());
    }

    /** One customer's dues, for the counter — 404 when they have no credit history. */
    @GetMapping("/{tenantPublicId}/credit/outstanding-for")
    public ResponseEntity<ContractResponse<CreditOutstanding>> creditOutstandingFor(
            @PathVariable String tenantPublicId,
            @RequestParam("mobile") String mobile) {
        requireTenant(tenantPublicId);
        CreditOutstanding c = creditService.outstandingFor(mobile);
        return c == null ? ResponseEntity.notFound().build() : ResponseEntity.ok(ContractResponse.of(c));
    }

    @PostMapping("/{tenantPublicId}/credit/payments")
    public ContractResponse<CreditOutstanding> recordCreditPayment(
            @PathVariable String tenantPublicId,
            @Valid @RequestBody PharmacyDtos.CreditPaymentRequest request,
            Principal principal) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(creditService.recordPayment(
                request.customerMobile(), request.amountPaise(), request.paidVia(),
                request.note(), actorOf(principal)));
    }

    /** Sales grouped by GST slab, for the accountant. */
    @GetMapping("/{tenantPublicId}/reports/gst-summary")
    public ContractResponse<List<GstSlabTotal>> gstSummary(
            @PathVariable String tenantPublicId,
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.gstSummary(from, to));
    }

    /** Corrects an existing medicine's GST/HSN/rack/reorder details. */
    @PostMapping("/{tenantPublicId}/catalog/skus/{skuPublicId}")
    public ContractResponse<SkuSummary> updateSku(@PathVariable String tenantPublicId,
                                                  @PathVariable String skuPublicId,
                                                  @Valid @RequestBody PharmacyDtos.UpdateSkuRequest request) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(catalogService.updateSku(skuPublicId, new CatalogService.UpdateSkuCommand(
                request.gstRateBp(), request.hsnCode(), request.rackLocation(),
                request.scheduleClass(), request.reorderLevel(), request.reorderQty())));
    }

    /** The refund history — where refunded money went. */
    @GetMapping("/{tenantPublicId}/returns/recent")
    public ContractResponse<List<RecentReturn>> recentReturns(
            @PathVariable String tenantPublicId,
            @RequestParam(value = "limit", defaultValue = "20") int limit) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(customerReturnService.recentReturns(limit));
    }

    // ---- Money view & day-close -------------------------------------------

    @GetMapping("/{tenantPublicId}/money/day")
    public ContractResponse<MoneyView> moneyView(
            @PathVariable String tenantPublicId,
            @RequestParam(value = "date", required = false)
            @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(dayCloseService.moneyView(date == null ? LocalDate.now() : date));
    }

    /** Dashboard tab totals for a Week/Month/Custom filter — Day still uses {@link #moneyView}. */
    @GetMapping("/{tenantPublicId}/sales/range-summary")
    public ContractResponse<DaySummary> rangeSummary(
            @PathVariable String tenantPublicId,
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.rangeSummary(from, to));
    }

    /** The Dashboard sales-trend line chart. */
    @GetMapping("/{tenantPublicId}/analytics/daily-totals")
    public ContractResponse<List<DailyTotal>> dailyTotals(
            @PathVariable String tenantPublicId,
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.dailyTotals(from, to));
    }

    /** The invoices data table's data source. */
    @GetMapping("/{tenantPublicId}/sales/in-range")
    public ContractResponse<List<SaleSummary>> salesInRange(
            @PathVariable String tenantPublicId,
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(value = "sortBy", defaultValue = "date") String sortBy,
            @RequestParam(value = "limit", defaultValue = "100") int limit) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.salesInRange(from, to, sortBy, limit));
    }

    /** "Same as last time" — the customer's most recent bill, for a one-tap rebill. */
    @GetMapping("/{tenantPublicId}/sales/last-for-mobile")
    public ResponseEntity<ContractResponse<SaleReceipt>> lastSaleForMobile(
            @PathVariable String tenantPublicId,
            @RequestParam("mobile") String mobile) {
        requireTenant(tenantPublicId);
        return saleQueryService.lastSaleForMobile(mobile)
                .map(r -> ResponseEntity.ok(ContractResponse.of(r)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    /**
     * The counter's "has this customer been here before?" lookup — keyed on mobile
     * alone, the identifier the khata and rebill chip already use. {@code
     * totalCount} of 0 is the client's cue to show "New customer" rather than an
     * empty accordion.
     */
    @GetMapping("/{tenantPublicId}/sales/customer-history")
    public ContractResponse<CustomerHistoryPage> customerHistory(
            @PathVariable String tenantPublicId,
            @RequestParam(value = "mobile", required = false) String mobile,
            @RequestParam(value = "page", defaultValue = "0") int page,
            @RequestParam(value = "size", defaultValue = "5") int size) {
        requireTenant(tenantPublicId);
        return ContractResponse.of(saleQueryService.customerHistory(mobile, page, size));
    }

    /** Voids a completed sale — the invoice table's "delete", which reverses stock rather than erasing anything. */
    @PostMapping("/{tenantPublicId}/sales/{salePublicId}/void")
    public ContractResponse<Void> voidSale(@PathVariable String tenantPublicId,
                                          @PathVariable String salePublicId,
                                          Principal principal) {
        requireTenant(tenantPublicId);
        counterSaleService.voidSale(salePublicId, actorOf(principal));
        return ContractResponse.of(null);
    }

    @PostMapping("/{tenantPublicId}/day-close")
    public ContractResponse<MoneyView> closeDay(@PathVariable String tenantPublicId,
                                                @Valid @RequestBody PharmacyDtos.DayCloseRequest request,
                                                Principal principal) {
        requireTenant(tenantPublicId);
        LocalDate date = request.date() == null ? LocalDate.now() : request.date();
        return ContractResponse.of(dayCloseService.close(
                date, request.countedCashPaise(), request.note(), actorOf(principal)));
    }

    private static void requireTenant(String tenantPublicId) {
        if (!tenantPublicId.equals(TenantContext.tenantPublicId())) {
            throw new IllegalArgumentException("Tenant mismatch");
        }
    }

    private static String actorOf(Principal principal) {
        return principal == null ? "system" : principal.getName();
    }
}
