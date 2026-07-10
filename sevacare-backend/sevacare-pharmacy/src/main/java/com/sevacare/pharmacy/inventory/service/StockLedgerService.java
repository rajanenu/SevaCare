package com.sevacare.pharmacy.inventory.service;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import com.sevacare.pharmacy.capability.spi.CapabilityPolicies;
import com.sevacare.pharmacy.capability.spi.PolicyKey;
import com.sevacare.pharmacy.capability.spi.PolicyMode;
import com.sevacare.pharmacy.inventory.spi.BatchAllocation;
import com.sevacare.pharmacy.inventory.spi.InsufficientStockException;
import com.sevacare.pharmacy.inventory.spi.InventoryEvents;
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.StockLedger;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.shared.event.DomainEvent;
import com.sevacare.shared.event.EventPublisher;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The one code path allowed to write stock.
 *
 * <p>{@code batch_balance} is a cache of {@code SUM(stock_ledger.qty_delta)} and
 * nothing else. A database trigger refuses any write to it that does not arrive
 * from here, recognised by a transaction-scoped GUC this class sets. That is
 * deliberately a tripwire and not a lock: the point is that the next person to
 * add a "quick stock fix" endpoint discovers the invariant in a failing test
 * rather than in a pharmacy's year-end audit.
 *
 * <p>Everything here is plain SQL rather than JPA. The ledger has no identity to
 * manage and never loads; the balance upsert needs {@code ON CONFLICT … WHERE}
 * that Criteria cannot express; and the row-lock ordering that prevents deadlocks
 * has to be visible in the code that depends on it.
 */
@Service
public class StockLedgerService implements StockLedger {

    private static final Logger log = LoggerFactory.getLogger(StockLedgerService.class);

    /**
     * Locks are taken in this order for every multi-row append, so two sales that
     * happen to share two batches cannot each hold what the other wants next.
     */
    private static final Comparator<StockMovement> CANONICAL_LOCK_ORDER =
            Comparator.comparing(StockMovement::batchPublicId).thenComparing(StockMovement::locationId);

    private final JdbcTemplate jdbcTemplate;
    private final EventPublisher eventPublisher;
    private final CapabilityPolicies policies;

    public StockLedgerService(JdbcTemplate jdbcTemplate,
                              EventPublisher eventPublisher,
                              CapabilityPolicies policies) {
        this.jdbcTemplate = jdbcTemplate;
        this.eventPublisher = eventPublisher;
        this.policies = policies;
    }

    @Override
    @Transactional
    public long append(StockMovement movement) {
        return appendAll(List.of(movement)).get(0);
    }

    @Override
    @Transactional
    public List<Long> appendAll(List<StockMovement> movements) {
        if (movements == null || movements.isEmpty()) {
            return List.of();
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());
        movements.forEach(StockLedgerService::validate);

        List<StockMovement> ordered = new ArrayList<>(movements);
        ordered.sort(CANONICAL_LOCK_ORDER);

        boolean enforceNoNegative = policies.modeOf(PolicyKey.NEGATIVE_STOCK).isEnforced();
        enableLedgerWrite();

        List<Long> ledgerIds = new ArrayList<>(ordered.size());
        for (StockMovement movement : ordered) {
            long ledgerId = insertLedgerRow(schema, tenantPublicId, movement);
            long balanceAfter = applyBalance(schema, movement, enforceNoNegative);
            ledgerIds.add(ledgerId);
            announce(movement, ledgerId, balanceAfter, enforceNoNegative);
        }
        return ledgerIds;
    }

    @Override
    @Transactional
    public long reverse(long ledgerId, String actor, String note) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        // The reversal keeps the original's reason: "why did this stock move" is
        // answered by the business event, not by the correction that fixed a typo.
        StockMovement original = jdbcTemplate.queryForObject(
                "SELECT sku_public_id, batch_public_id, location_id, qty_delta, reason, ref_type, ref_id " +
                "FROM " + schema + ".stock_ledger WHERE ledger_id = ?",
                (rs, i) -> new StockMovement(
                        rs.getString("sku_public_id"),
                        rs.getString("batch_public_id"),
                        rs.getString("location_id"),
                        -rs.getInt("qty_delta"),
                        MovementReason.valueOf(rs.getString("reason")),
                        rs.getString("ref_type"),
                        rs.getString("ref_id"),
                        actor, Instant.now(), null, ledgerId,
                        note == null ? "reversal of ledger " + ledgerId : note),
                ledgerId);

        // A reversal must post even when it drives the balance negative -- refusing
        // to undo a mistake because undoing it looks like a shortage would leave
        // the wrong number in the register permanently.
        return appendAll(List.of(original)).get(0);
    }

    @Override
    @Transactional
    public BatchAllocation.Result allocateFefo(String skuPublicId, String locationId, int qtyBaseUnits) {
        if (qtyBaseUnits <= 0) {
            throw new IllegalArgumentException("Allocation quantity must be positive");
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        // FOR NO KEY UPDATE holds the candidate balance rows for the rest of this
        // transaction, so the append that follows cannot be beaten to the stock by
        // a concurrent sale. This is the concurrency control -- there is no Redis,
        // no queue, and at pharmacy write rates there does not need to be.
        List<Candidate> candidates = jdbcTemplate.query(
                "SELECT bb.batch_public_id, bb.qty, b.expiry_date, b.mrp_paise " +
                "FROM " + schema + ".batch_balance bb " +
                "JOIN " + schema + ".batch b ON b.batch_public_id = bb.batch_public_id " +
                "WHERE bb.sku_public_id = ? AND bb.location_id = ? AND bb.qty > 0 " +
                "  AND b.batch_status IN ('ACTIVE', 'NEAR_EXPIRY') " +
                // Belt and braces: batch_status is maintained by a daily scheduler,
                // and expiry is re-checked against the date at every dispense.
                "  AND (b.expiry_date IS NULL OR b.expiry_date >= CURRENT_DATE) " +
                "ORDER BY b.expiry_date NULLS LAST, bb.batch_public_id " +
                "FOR NO KEY UPDATE OF bb",
                (rs, i) -> new Candidate(
                        rs.getString("batch_public_id"),
                        rs.getLong("qty"),
                        rs.getDate("expiry_date") == null ? null : rs.getDate("expiry_date").toLocalDate(),
                        rs.getLong("mrp_paise")),
                skuPublicId, locationId);

        List<BatchAllocation> allocations = new ArrayList<>();
        int remaining = qtyBaseUnits;
        for (Candidate candidate : candidates) {
            if (remaining == 0) {
                break;
            }
            int take = (int) Math.min(remaining, candidate.qty());
            allocations.add(new BatchAllocation(
                    candidate.batchPublicId(), take, candidate.expiryDate(), candidate.mrpPaise()));
            remaining -= take;
        }
        return new BatchAllocation.Result(List.copyOf(allocations), remaining);
    }

    @Override
    @Transactional(readOnly = true)
    public long balanceOf(String skuPublicId, String locationId) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        Long qty = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(qty), 0) FROM " + schema + ".batch_balance " +
                "WHERE sku_public_id = ? AND location_id = ?",
                Long.class, skuPublicId, locationId);
        return qty == null ? 0L : qty;
    }

    @Override
    @Transactional(readOnly = true)
    public long balanceOfBatch(String batchPublicId, String locationId) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        Long qty = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(qty), 0) FROM " + schema + ".batch_balance " +
                "WHERE batch_public_id = ? AND location_id = ?",
                Long.class, batchPublicId, locationId);
        return qty == null ? 0L : qty;
    }

    /**
     * Rebuilds every balance from the ledger. This is what "the balance is a
     * cache" means operationally: if it is ever wrong, it can be made right
     * without anyone deciding what the truth was. Cheap enough to run in a test
     * on every ledger scenario, which is exactly what proves the claim.
     */
    @Transactional
    public void rebuildBalancesFromLedger() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        enableLedgerWrite();
        jdbcTemplate.update("DELETE FROM " + schema + ".batch_balance");
        jdbcTemplate.update(
                "INSERT INTO " + schema + ".batch_balance (sku_public_id, batch_public_id, location_id, qty, version) " +
                "SELECT sku_public_id, batch_public_id, location_id, SUM(qty_delta), 1 " +
                "FROM " + schema + ".stock_ledger GROUP BY sku_public_id, batch_public_id, location_id");
        log.info("stock_balances_rebuilt schema={}", schema);
    }

    private long insertLedgerRow(String schema, String tenantPublicId, StockMovement movement) {
        Instant occurredAt = movement.occurredAt() == null ? Instant.now() : movement.occurredAt();
        Long ledgerId = jdbcTemplate.queryForObject(
                "INSERT INTO " + schema + ".stock_ledger " +
                "(tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason, " +
                " ref_type, ref_id, actor, occurred_at, device_seq, correction_of, note) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING ledger_id",
                Long.class,
                tenantPublicId, movement.skuPublicId(), movement.batchPublicId(), movement.locationId(),
                movement.qtyDelta(), movement.reason().name(), movement.refType(), movement.refId(),
                movement.actor(), Timestamp.from(occurredAt), movement.deviceSeq(),
                movement.correctionOf(), movement.note());
        if (ledgerId == null) {
            throw new IllegalStateException("Ledger insert returned no id");
        }
        return ledgerId;
    }

    /** @return the balance after this movement */
    private long applyBalance(String schema, StockMovement movement, boolean enforceNoNegative) {
        if (movement.isOutbound() && enforceNoNegative) {
            List<Long> after = jdbcTemplate.queryForList(
                    "UPDATE " + schema + ".batch_balance " +
                    "SET qty = qty + ?, version = version + 1, updated_at = CURRENT_TIMESTAMP " +
                    "WHERE batch_public_id = ? AND location_id = ? AND qty + ? >= 0 " +
                    "RETURNING qty",
                    Long.class,
                    movement.qtyDelta(), movement.batchPublicId(), movement.locationId(), movement.qtyDelta());
            if (after.isEmpty()) {
                // Either no balance row at all, or not enough in it. Both mean the
                // same thing to a caller under ENFORCE, and the transaction rolls
                // back -- including the ledger row written moments ago.
                throw new InsufficientStockException(
                        movement.batchPublicId(), movement.locationId(), movement.qtyDelta());
            }
            return after.get(0);
        }

        Long after = jdbcTemplate.queryForObject(
                "INSERT INTO " + schema + ".batch_balance (sku_public_id, batch_public_id, location_id, qty, version) " +
                "VALUES (?, ?, ?, ?, 1) " +
                "ON CONFLICT (batch_public_id, location_id) DO UPDATE " +
                "SET qty = " + schema + ".batch_balance.qty + EXCLUDED.qty, " +
                "    version = " + schema + ".batch_balance.version + 1, " +
                "    updated_at = CURRENT_TIMESTAMP " +
                "RETURNING qty",
                Long.class,
                movement.skuPublicId(), movement.batchPublicId(), movement.locationId(), (long) movement.qtyDelta());
        if (after == null) {
            throw new IllegalStateException("Balance upsert returned no quantity");
        }
        return after;
    }

    private void announce(StockMovement movement, long ledgerId, long balanceAfter, boolean enforceNoNegative) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("ledgerId", ledgerId);
        payload.put("skuPublicId", movement.skuPublicId());
        payload.put("batchPublicId", movement.batchPublicId());
        payload.put("locationId", movement.locationId());
        payload.put("qtyDelta", movement.qtyDelta());
        payload.put("reason", movement.reason().name());
        payload.put("refType", movement.refType());
        payload.put("refId", movement.refId());
        payload.put("balanceAfter", balanceAfter);

        eventPublisher.publish(DomainEvent
                .of(InventoryEvents.STOCK_MOVED, "Batch", movement.batchPublicId(), payload)
                .withActor(movement.actor()));

        if (balanceAfter < 0 && !enforceNoNegative
                && policies.modeOf(PolicyKey.NEGATIVE_STOCK) == PolicyMode.SUGGEST) {
            eventPublisher.publish(DomainEvent.of(
                    InventoryEvents.STOCK_WENT_NEGATIVE, "Batch", movement.batchPublicId(),
                    Map.of("skuPublicId", movement.skuPublicId(),
                           "batchPublicId", movement.batchPublicId(),
                           "locationId", movement.locationId(),
                           "balance", balanceAfter)));
            log.warn("stock_balance_negative sku={} batch={} location={} balance={}",
                    movement.skuPublicId(), movement.batchPublicId(), movement.locationId(), balanceAfter);
        }
    }

    /**
     * Opens the trigger on {@code batch_balance} for this transaction only.
     * {@code SET LOCAL} is reverted at commit or rollback, so the permission can
     * never leak to the next borrower of a pooled connection — and outside a
     * transaction it does nothing at all, which correctly blocks any balance
     * write that was never atomic with a ledger append.
     */
    private void enableLedgerWrite() {
        if (!TransactionSynchronizationManager.isActualTransactionActive()) {
            throw new IllegalStateException(
                    "Stock ledger appends must run inside a transaction: the ledger row and the "
                    + "balance it feeds have to commit together or not at all");
        }
        jdbcTemplate.execute("SET LOCAL sevacare.ledger_append = 'on'");
    }

    private static void validate(StockMovement movement) {
        if (movement.qtyDelta() == 0) {
            throw new IllegalArgumentException("A stock movement of zero units is not a movement");
        }
        if (movement.reason() == null) {
            throw new IllegalArgumentException("Every stock movement needs a reason");
        }
        if (movement.skuPublicId() == null || movement.batchPublicId() == null || movement.locationId() == null) {
            throw new IllegalArgumentException("A stock movement needs a sku, a batch and a location");
        }
    }

    private record Candidate(String batchPublicId, long qty, java.time.LocalDate expiryDate, long mrpPaise) {
    }
}
