package com.sevacare.pharmacy.procurement.service;

import java.sql.Date;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.catalog.spi.CatalogLookup;
import com.sevacare.pharmacy.catalog.spi.SkuSummary;
import com.sevacare.pharmacy.inventory.spi.BatchIntake;
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.NewBatch;
import com.sevacare.pharmacy.inventory.spi.StockLedger;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.pharmacy.procurement.spi.GrnSummary;
import com.sevacare.pharmacy.procurement.spi.PostedGrn;
import com.sevacare.pharmacy.procurement.spi.ProcurementEvents;
import com.sevacare.shared.event.DomainEvent;
import com.sevacare.shared.event.EventPublisher;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The goods receipt: a delivery becomes batches, ledger rows and a document, in
 * one transaction. This replaces nothing — the quick single-batch receive stays
 * for the strip bought loose from the shop next door — but a real delivery is a
 * multi-line invoice from a distributor, and recording it as one document is
 * what makes supplier price history, payables and the "10+1" scheme's true
 * margin computable at all.
 *
 * <p>A GRN needs no supplier and no purchase order (blueprint §8.3): the owner
 * phones the distributor, a carton arrives, and refusing to record that reality
 * is how stock goes wrong. Structure is earned, not demanded (Law 3).
 */
@Service
public class GrnService {

    private static final Logger log = LoggerFactory.getLogger(GrnService.class);

    private final JdbcTemplate jdbcTemplate;
    private final CatalogLookup catalog;
    private final BatchIntake batchIntake;
    private final StockLedger stockLedger;
    private final EventPublisher eventPublisher;

    public GrnService(JdbcTemplate jdbcTemplate,
                      CatalogLookup catalog,
                      BatchIntake batchIntake,
                      StockLedger stockLedger,
                      EventPublisher eventPublisher) {
        this.jdbcTemplate = jdbcTemplate;
        this.catalog = catalog;
        this.batchIntake = batchIntake;
        this.stockLedger = stockLedger;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public PostedGrn post(PostGrnCommand command) {
        if (command.lines() == null || command.lines().isEmpty()) {
            throw new IllegalArgumentException("A goods receipt needs at least one line");
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());
        String location = stockLedger.defaultLocationId();

        if (command.supplierPublicId() != null && !command.supplierPublicId().isBlank()) {
            requireSupplier(schema, command.supplierPublicId());
        }

        Long seq = jdbcTemplate.queryForObject(
                "SELECT nextval('" + schema + ".grn_public_id_seq')", Long.class);
        String grnPublicId = "GRN-" + String.format("%06d", seq);

        List<PreparedLine> prepared = new ArrayList<>();
        List<StockMovement> movements = new ArrayList<>();
        long totalQty = 0;
        long totalCost = 0;

        for (PostGrnCommand.LineRequest line : command.lines()) {
            if (line.qtyBaseUnits() <= 0) {
                throw new IllegalArgumentException("A GRN line needs a positive billed quantity");
            }
            if (line.freeQtyBaseUnits() < 0) {
                throw new IllegalArgumentException("Free quantity cannot be negative");
            }
            SkuSummary sku = catalog.findSku(line.skuPublicId())
                    .orElseThrow(() -> new IllegalArgumentException("Unknown SKU: " + line.skuPublicId()));

            int unitsIn = line.qtyBaseUnits() + line.freeQtyBaseUnits();
            long lineCost = line.purchasePricePaise() == null
                    ? 0 : line.purchasePricePaise() * line.qtyBaseUnits();

            // The batch's unit cost is what was PAID divided by ALL units received,
            // free ones included — the "10+1" scheme lowers the cost of every unit,
            // and true margin (owner's Money view) is computed off this number.
            Long effectiveUnitCost = line.purchasePricePaise() == null
                    ? null : (lineCost + unitsIn / 2) / unitsIn;

            String batchPublicId = batchIntake.findOrCreateBatch(new NewBatch(
                    sku.skuPublicId(), line.batchNo(), line.expiryDate(),
                    line.mrpPaise(), effectiveUnitCost, trimToNull(command.supplierPublicId())));

            movements.add(StockMovement.of(
                    sku.skuPublicId(), batchPublicId, location, unitsIn,
                    MovementReason.GRN, "GRN", grnPublicId, command.actor()));
            prepared.add(new PreparedLine(sku, batchPublicId, line));
            totalQty += unitsIn;
            totalCost += lineCost;
        }

        stockLedger.appendAll(movements);

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".goods_receipt " +
                "(grn_public_id, tenant_public_id, supplier_public_id, supplier_invoice_no, invoice_date, " +
                " line_count, total_qty_base, total_cost_paise, actor, note) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                grnPublicId, tenantPublicId, trimToNull(command.supplierPublicId()),
                trimToNull(command.supplierInvoiceNo()),
                command.invoiceDate() == null ? null : Date.valueOf(command.invoiceDate()),
                prepared.size(), totalQty, totalCost, command.actor(), trimToNull(command.note()));

        for (PreparedLine pl : prepared) {
            jdbcTemplate.update(
                    "INSERT INTO " + schema + ".grn_line " +
                    "(grn_public_id, sku_public_id, batch_public_id, batch_no, expiry_date, " +
                    " qty_base_units, free_qty_base_units, mrp_paise, purchase_price_paise) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    grnPublicId, pl.sku().skuPublicId(), pl.batchPublicId(),
                    pl.request().batchNo().trim(),
                    pl.request().expiryDate() == null ? null : Date.valueOf(pl.request().expiryDate()),
                    pl.request().qtyBaseUnits(), pl.request().freeQtyBaseUnits(),
                    pl.request().mrpPaise(), pl.request().purchasePricePaise());
        }

        announce(grnPublicId, command, prepared.size(), totalCost);
        log.info("pharmacy_grn_posted grn={} lines={} qty={} cost_paise={}",
                grnPublicId, prepared.size(), totalQty, totalCost);

        List<PostedGrn.Line> receiptLines = new ArrayList<>();
        for (PreparedLine pl : prepared) {
            receiptLines.add(new PostedGrn.Line(
                    pl.sku().skuPublicId(), pl.sku().brandName(), pl.batchPublicId(),
                    pl.request().batchNo().trim(), pl.request().qtyBaseUnits(),
                    pl.request().freeQtyBaseUnits(),
                    stockLedger.balanceOfBatch(pl.batchPublicId(), location)));
        }
        return new PostedGrn(grnPublicId, trimToNull(command.supplierPublicId()),
                prepared.size(), totalQty, totalCost, receiptLines);
    }

    @Transactional(readOnly = true)
    public List<GrnSummary> recentGrns(int limit) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        int capped = Math.min(Math.max(limit, 1), 50);
        return jdbcTemplate.query(
                "SELECT g.grn_public_id, g.supplier_public_id, s.supplier_name, g.supplier_invoice_no, " +
                "       g.line_count, g.total_qty_base, g.total_cost_paise, g.received_at " +
                "FROM " + schema + ".goods_receipt g " +
                "LEFT JOIN " + schema + ".supplier s ON s.supplier_public_id = g.supplier_public_id " +
                "ORDER BY g.received_at DESC LIMIT ?",
                (rs, i) -> new GrnSummary(
                        rs.getString("grn_public_id"),
                        rs.getString("supplier_public_id"),
                        rs.getString("supplier_name"),
                        rs.getString("supplier_invoice_no"),
                        rs.getInt("line_count"),
                        rs.getLong("total_qty_base"),
                        rs.getLong("total_cost_paise"),
                        rs.getTimestamp("received_at").toInstant()),
                capped);
    }

    private void requireSupplier(String schema, String supplierPublicId) {
        Integer found = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".supplier WHERE supplier_public_id = ? AND active",
                Integer.class, supplierPublicId);
        if (found == null || found == 0) {
            throw new IllegalArgumentException("Unknown supplier: " + supplierPublicId);
        }
    }

    private void announce(String grnPublicId, PostGrnCommand command, int lines, long totalCost) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("grnPublicId", grnPublicId);
        payload.put("supplierPublicId", command.supplierPublicId());
        payload.put("lineCount", lines);
        payload.put("totalCostPaise", totalCost);
        eventPublisher.publish(DomainEvent
                .of(ProcurementEvents.GRN_POSTED, "GoodsReceipt", grnPublicId, payload)
                .withActor(command.actor()));
    }

    private static String trimToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private record PreparedLine(SkuSummary sku, String batchPublicId, PostGrnCommand.LineRequest request) {
    }
}
