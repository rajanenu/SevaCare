package com.sevacare.pharmacy.inventory.service;

import java.time.LocalDate;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.inventory.spi.BatchIntake;
import com.sevacare.pharmacy.inventory.spi.GrnReceipt;
import com.sevacare.pharmacy.inventory.spi.LowStockItem;
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.NearExpiryBatch;
import com.sevacare.pharmacy.inventory.spi.NewBatch;
import com.sevacare.pharmacy.inventory.spi.StockLedger;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Batches and locations — the nouns the ledger moves stock between. Quantities
 * live nowhere in this class; they are only ever a sum of ledger rows.
 */
@Service
public class InventoryService implements BatchIntake {

    private static final Logger log = LoggerFactory.getLogger(InventoryService.class);

    private final JdbcTemplate jdbcTemplate;
    private final StockLedger stockLedger;
    private final int nearExpiryDays;

    public InventoryService(JdbcTemplate jdbcTemplate,
                            StockLedger stockLedger,
                            @Value("${sevacare.pharmacy.near-expiry-days:90}") int nearExpiryDays) {
        this.jdbcTemplate = jdbcTemplate;
        this.stockLedger = stockLedger;
        this.nearExpiryDays = nearExpiryDays;
    }

    /**
     * Receiving stock: the batch (created if new) and the ledger entry that puts
     * quantity into it, in one transaction. This is the only inbound counterpart
     * to a sale, and like a sale it writes stock only through the ledger.
     */
    @Transactional
    public GrnReceipt receiveStock(CreateBatchCommand batch, int qtyBaseUnits, String actor) {
        if (qtyBaseUnits <= 0) {
            throw new IllegalArgumentException("Received quantity must be positive");
        }
        String location = stockLedger.defaultLocationId();
        String batchPublicId = findOrCreateBatch(batch);
        long ledgerId = stockLedger.append(StockMovement.of(
                batch.skuPublicId(), batchPublicId, location, qtyBaseUnits,
                MovementReason.GRN, "GRN", batchPublicId, actor));
        long balance = stockLedger.balanceOfBatch(batchPublicId, location);
        return new GrnReceipt(batchPublicId, batch.skuPublicId(), qtyBaseUnits, balance, ledgerId);
    }

    /**
     * Batches with stock on hand that expire within the near-expiry window (or
     * already have). The queue that gets money back from a supplier before the
     * claim window closes; ordered soonest-to-expire first.
     */
    @Transactional(readOnly = true)
    public List<NearExpiryBatch> nearExpiryBatches() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbcTemplate.query(
                "SELECT b.sku_public_id, s.brand_name, b.batch_public_id, b.batch_no, " +
                "       b.expiry_date, b.batch_status, COALESCE(SUM(bb.qty), 0) AS on_hand " +
                "FROM " + schema + ".batch b " +
                "JOIN " + schema + ".medicine_sku s ON s.sku_public_id = b.sku_public_id " +
                "LEFT JOIN " + schema + ".batch_balance bb ON bb.batch_public_id = b.batch_public_id " +
                "WHERE b.expiry_date IS NOT NULL " +
                "  AND b.expiry_date <= CURRENT_DATE + (? * INTERVAL '1 day') " +
                "  AND b.batch_status IN ('ACTIVE', 'NEAR_EXPIRY', 'EXPIRED') " +
                "GROUP BY b.sku_public_id, s.brand_name, b.batch_public_id, b.batch_no, b.expiry_date, b.batch_status " +
                "HAVING COALESCE(SUM(bb.qty), 0) > 0 " +
                "ORDER BY b.expiry_date",
                (rs, i) -> new NearExpiryBatch(
                        rs.getString("sku_public_id"),
                        rs.getString("brand_name"),
                        rs.getString("batch_public_id"),
                        rs.getString("batch_no"),
                        rs.getDate("expiry_date") == null ? null : rs.getDate("expiry_date").toLocalDate(),
                        rs.getLong("on_hand"),
                        rs.getString("batch_status")),
                nearExpiryDays);
    }

    /**
     * SKUs whose on-hand quantity has fallen to or below the reorder level the
     * tenant set. Only tracked SKUs appear — an untracked one has no opinion about
     * when it is low, so listing it would be noise, not a shopping list.
     */
    @Transactional(readOnly = true)
    public List<LowStockItem> lowStockItems() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbcTemplate.query(
                "SELECT s.sku_public_id, s.brand_name, s.reorder_level, s.reorder_qty, " +
                "       COALESCE(SUM(bb.qty), 0) AS on_hand " +
                "FROM " + schema + ".medicine_sku s " +
                "LEFT JOIN " + schema + ".batch_balance bb ON bb.sku_public_id = s.sku_public_id " +
                "WHERE s.active AND s.reorder_level IS NOT NULL " +
                "GROUP BY s.sku_public_id, s.brand_name, s.reorder_level, s.reorder_qty " +
                "HAVING COALESCE(SUM(bb.qty), 0) <= s.reorder_level " +
                "ORDER BY COALESCE(SUM(bb.qty), 0)",
                (rs, i) -> new LowStockItem(
                        rs.getString("sku_public_id"),
                        rs.getString("brand_name"),
                        rs.getLong("on_hand"),
                        rs.getInt("reorder_level"),
                        (Integer) rs.getObject("reorder_qty")),
                new Object[] {});
    }

    /** The {@link BatchIntake} SPI: how procurement and returns create batches. */
    @Override
    @Transactional
    public String findOrCreateBatch(NewBatch batch) {
        return findOrCreateBatch(new CreateBatchCommand(
                batch.skuPublicId(), batch.batchNo(), batch.expiryDate(),
                batch.mrpPaise(), batch.purchasePricePaise(), batch.supplierPublicId()));
    }

    /**
     * Finds the batch or creates it. Receiving the same batch number for the same
     * SKU a second time is not a duplicate — it is the second truck — so this is
     * idempotent rather than an error, which is what lets a GRN be re-posted after
     * a network failure without splitting one carton across two batch records.
     *
     * <p>Stock received already expired lands as {@code EXPIRED}, unsellable from
     * the moment it arrives. That happens, and pretending it did not is how it
     * ends up dispensed.
     */
    @Transactional
    public String findOrCreateBatch(CreateBatchCommand command) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());

        if (command.batchNo() == null || command.batchNo().isBlank()) {
            throw new IllegalArgumentException("A batch needs a batch number");
        }
        if (command.mrpPaise() < 0) {
            throw new IllegalArgumentException("MRP cannot be negative");
        }

        List<ExistingBatch> existing = jdbcTemplate.query(
                "SELECT batch_public_id, mrp_paise FROM " + schema + ".batch " +
                "WHERE sku_public_id = ? AND upper(batch_no) = upper(?)",
                (rs, i) -> new ExistingBatch(rs.getString("batch_public_id"), rs.getLong("mrp_paise")),
                command.skuPublicId(), command.batchNo());

        if (!existing.isEmpty()) {
            ExistingBatch batch = existing.get(0);
            if (batch.mrpPaise() != command.mrpPaise()) {
                // The batch is identified by what is printed on the pack. Two MRPs
                // under one batch number is a typo far more often than it is a
                // repricing, and overwriting the first receipt's MRP would silently
                // reprice stock already sold against it.
                log.warn("batch_mrp_mismatch batch={} storedMrpPaise={} receivedMrpPaise={}",
                        batch.batchPublicId(), batch.mrpPaise(), command.mrpPaise());
            }
            return batch.batchPublicId();
        }

        String batchPublicId = nextBatchPublicId(schema);
        jdbcTemplate.update(
                "INSERT INTO " + schema + ".batch " +
                "(batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, " +
                " mrp_paise, purchase_price_paise, supplier_public_id, batch_status) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                batchPublicId, tenantPublicId, command.skuPublicId(), command.batchNo().trim(),
                command.expiryDate(), command.mrpPaise(), command.purchasePricePaise(),
                command.supplierPublicId(), statusFor(command.expiryDate()));
        return batchPublicId;
    }

    /**
     * Moves ACTIVE batches to NEAR_EXPIRY and then EXPIRED as the calendar turns.
     *
     * <p>This is a projection of the date, not a source of truth: the FEFO
     * allocator re-checks {@code expiry_date} on every dispense, so a day when
     * this never runs is a day with a stale near-expiry queue, not a day when
     * expired stock can be sold. Belt and braces, because a scheduled task racing
     * a request has bitten this codebase before.
     */
    @Transactional
    public int refreshBatchStatuses() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        int expired = jdbcTemplate.update(
                "UPDATE " + schema + ".batch SET batch_status = 'EXPIRED', updated_at = CURRENT_TIMESTAMP " +
                "WHERE expiry_date IS NOT NULL AND expiry_date < CURRENT_DATE " +
                "  AND batch_status IN ('ACTIVE', 'NEAR_EXPIRY')");

        int nearExpiry = jdbcTemplate.update(
                "UPDATE " + schema + ".batch SET batch_status = 'NEAR_EXPIRY', updated_at = CURRENT_TIMESTAMP " +
                "WHERE expiry_date IS NOT NULL AND expiry_date >= CURRENT_DATE " +
                "  AND expiry_date <= CURRENT_DATE + (? * INTERVAL '1 day') " +
                "  AND batch_status = 'ACTIVE'",
                nearExpiryDays);

        return expired + nearExpiry;
    }

    @Transactional(readOnly = true)
    public String defaultLocationId() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        List<String> rows = jdbcTemplate.queryForList(
                "SELECT location_id FROM " + schema + ".stock_location WHERE is_default AND active",
                String.class);
        if (rows.isEmpty()) {
            throw new IllegalStateException("Tenant has no default stock location");
        }
        return rows.get(0);
    }

    private String statusFor(LocalDate expiryDate) {
        if (expiryDate == null) {
            return "ACTIVE";
        }
        LocalDate today = LocalDate.now();
        if (expiryDate.isBefore(today)) {
            return "EXPIRED";
        }
        return expiryDate.isBefore(today.plusDays(nearExpiryDays)) ? "NEAR_EXPIRY" : "ACTIVE";
    }

    private String nextBatchPublicId(String schema) {
        Long value = jdbcTemplate.queryForObject(
                "SELECT nextval('" + schema + ".batch_public_id_seq')", Long.class);
        if (value == null) {
            throw new IllegalStateException("Could not generate a batch id");
        }
        return "BAT-" + String.format("%06d", value);
    }

    private record ExistingBatch(String batchPublicId, long mrpPaise) {
    }
}
