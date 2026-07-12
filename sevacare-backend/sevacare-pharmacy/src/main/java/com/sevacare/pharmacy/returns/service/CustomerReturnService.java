package com.sevacare.pharmacy.returns.service;

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
import com.sevacare.pharmacy.inventory.spi.MovementReason;
import com.sevacare.pharmacy.inventory.spi.StockLedger;
import com.sevacare.pharmacy.inventory.spi.StockMovement;
import com.sevacare.pharmacy.returns.spi.PostedReturn;
import com.sevacare.pharmacy.returns.spi.RecentReturn;
import com.sevacare.pharmacy.returns.spi.ReturnableLine;
import com.sevacare.pharmacy.returns.spi.ReturnsEvents;
import com.sevacare.shared.event.DomainEvent;
import com.sevacare.shared.event.EventPublisher;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Customer returns — always against a bill, because the bill is the provenance
 * a refund needs and a drug inspector asks for. The return document, the refund
 * amount and the stock movement commit in one transaction, exactly as the sale
 * they reverse did.
 *
 * <p>The refund is computed server-side from the sale line's own net price
 * (never re-priced at today's MRP), prorated per unit with the remainder on the
 * last unit — so returning a full line refunds exactly what was paid for it,
 * and a stale client screen can never mint money.
 *
 * <p>Disposition is per line: RESTOCK appends {@code RETURN_IN} at the counter;
 * QUARANTINE appends it at the QUARANTINE location, where the FEFO allocator
 * never looks — an opened strip must not reach the next customer.
 */
@Service
public class CustomerReturnService {

    private static final Logger log = LoggerFactory.getLogger(CustomerReturnService.class);

    private final JdbcTemplate jdbcTemplate;
    private final StockLedger stockLedger;
    private final EventPublisher eventPublisher;

    public CustomerReturnService(JdbcTemplate jdbcTemplate,
                                 StockLedger stockLedger,
                                 EventPublisher eventPublisher) {
        this.jdbcTemplate = jdbcTemplate;
        this.stockLedger = stockLedger;
        this.eventPublisher = eventPublisher;
    }

    /** What of this bill can still come back, line by line. */
    @Transactional(readOnly = true)
    public List<ReturnableLine> returnableLines(String salePublicId) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        requireCompletedSale(schema, salePublicId);
        return jdbcTemplate.query(
                "SELECT l.sku_public_id, s.brand_name, l.batch_public_id, l.qty_base_units, " +
                "       (l.gross_paise - l.discount_paise) AS net_paise, " +
                "       COALESCE((SELECT SUM(rl.qty_base_units) " +
                "                 FROM " + schema + ".customer_return_line rl " +
                "                 JOIN " + schema + ".customer_return r ON r.return_public_id = rl.return_public_id " +
                "                 WHERE r.sale_public_id = l.sale_public_id " +
                "                   AND rl.sku_public_id = l.sku_public_id " +
                "                   AND rl.batch_public_id = l.batch_public_id), 0) AS returned " +
                "FROM " + schema + ".sale_line l " +
                "JOIN " + schema + ".medicine_sku s ON s.sku_public_id = l.sku_public_id " +
                "WHERE l.sale_public_id = ? ORDER BY l.line_id",
                (rs, i) -> {
                    int qtySold = rs.getInt("qty_base_units");
                    long net = rs.getLong("net_paise");
                    return new ReturnableLine(
                            rs.getString("sku_public_id"),
                            rs.getString("brand_name"),
                            rs.getString("batch_public_id"),
                            qtySold,
                            rs.getInt("returned"),
                            net,
                            qtySold == 0 ? 0 : net / qtySold);
                },
                salePublicId);
    }

    @Transactional
    public PostedReturn post(PostReturnCommand command) {
        if (command.lines() == null || command.lines().isEmpty()) {
            throw new IllegalArgumentException("A return needs at least one line");
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());
        requireCompletedSale(schema, command.salePublicId());

        String counterLocation = stockLedger.defaultLocationId();
        String quarantineLocation = quarantineLocationId(schema, counterLocation);
        PaymentMode refundMode = PaymentMode.parse(command.refundMode());

        Long seq = jdbcTemplate.queryForObject(
                "SELECT nextval('" + schema + ".customer_return_public_id_seq')", Long.class);
        String returnPublicId = "RET-" + String.format("%06d", seq);

        Map<String, ReturnableLine> returnable = new HashMap<>();
        for (ReturnableLine line : returnableLines(command.salePublicId())) {
            returnable.put(line.skuPublicId() + "|" + line.batchPublicId(), line);
        }

        List<StockMovement> movements = new ArrayList<>();
        List<PostedReturn.Line> lines = new ArrayList<>();
        long refundTotal = 0;

        for (PostReturnCommand.LineRequest req : command.lines()) {
            if (req.qtyBaseUnits() <= 0) {
                throw new IllegalArgumentException("A return line needs a positive quantity");
            }
            String disposition = req.disposition() == null ? "RESTOCK" : req.disposition().toUpperCase();
            if (!"RESTOCK".equals(disposition) && !"QUARANTINE".equals(disposition)) {
                throw new IllegalArgumentException("Disposition must be RESTOCK or QUARANTINE");
            }
            ReturnableLine sold = returnable.get(req.skuPublicId() + "|" + req.batchPublicId());
            if (sold == null) {
                throw new IllegalArgumentException(
                        "This bill has no line for that item and batch — a return follows its bill exactly.");
            }
            if (req.qtyBaseUnits() > sold.qtyReturnable()) {
                throw new IllegalArgumentException(
                        sold.brandName() + ": only " + sold.qtyReturnable()
                        + " can still be returned on this bill (sold " + sold.qtySold()
                        + ", already returned " + sold.qtyAlreadyReturned() + ").");
            }

            // Whole-line returns refund the exact net paid; partial returns get the
            // prorated floor — the remainder stays with the store, not the drawer.
            long amount = req.qtyBaseUnits() == sold.qtySold()
                    ? sold.netPaise()
                    : sold.netPaise() * req.qtyBaseUnits() / sold.qtySold();
            refundTotal += amount;

            String location = "QUARANTINE".equals(disposition) ? quarantineLocation : counterLocation;
            movements.add(StockMovement.of(
                    req.skuPublicId(), req.batchPublicId(), location, req.qtyBaseUnits(),
                    MovementReason.RETURN_IN, "RETURN", returnPublicId, command.actor()));
            lines.add(new PostedReturn.Line(
                    req.skuPublicId(), sold.brandName(), req.batchPublicId(),
                    req.qtyBaseUnits(), amount, disposition));
        }

        stockLedger.appendAll(movements);

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".customer_return " +
                "(return_public_id, tenant_public_id, sale_public_id, refund_paise, refund_mode, " +
                " reason, actor, return_date) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                returnPublicId, tenantPublicId, command.salePublicId(), refundTotal, refundMode.name(),
                trimToNull(command.reason()), command.actor(), java.sql.Date.valueOf(LocalDate.now()));

        for (PostedReturn.Line line : lines) {
            jdbcTemplate.update(
                    "INSERT INTO " + schema + ".customer_return_line " +
                    "(return_public_id, sku_public_id, batch_public_id, qty_base_units, amount_paise, disposition) " +
                    "VALUES (?, ?, ?, ?, ?, ?)",
                    returnPublicId, line.skuPublicId(), line.batchPublicId(),
                    line.qtyBaseUnits(), line.amountPaise(), line.disposition());
        }

        announce(returnPublicId, command.salePublicId(), refundTotal, refundMode, command.actor());
        log.info("pharmacy_customer_return_posted return={} sale={} refund_paise={}",
                returnPublicId, command.salePublicId(), refundTotal);

        return new PostedReturn(returnPublicId, command.salePublicId(), refundTotal,
                refundMode.name(), lines);
    }

    /** The refund history — where refunded money went, per past return. */
    @Transactional(readOnly = true)
    public List<RecentReturn> recentReturns(int limit) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        int capped = Math.min(Math.max(limit, 1), 100);
        return jdbcTemplate.query(
                "SELECT r.return_public_id, r.sale_public_id, sa.invoice_no, r.refund_paise, " +
                "       r.refund_mode, r.reason, r.returned_at, " +
                "       (SELECT COUNT(*) FROM " + schema + ".customer_return_line rl " +
                "                       WHERE rl.return_public_id = r.return_public_id) AS lines " +
                "FROM " + schema + ".customer_return r " +
                "JOIN " + schema + ".sale sa ON sa.sale_public_id = r.sale_public_id " +
                "ORDER BY r.returned_at DESC LIMIT ?",
                (rs, i) -> new RecentReturn(
                        rs.getString("return_public_id"),
                        rs.getString("sale_public_id"),
                        rs.getString("invoice_no"),
                        rs.getLong("refund_paise"),
                        rs.getString("refund_mode"),
                        rs.getString("reason"),
                        rs.getTimestamp("returned_at").toInstant(),
                        rs.getInt("lines")),
                capped);
    }

    private void requireCompletedSale(String schema, String salePublicId) {
        List<String> status = jdbcTemplate.queryForList(
                "SELECT status FROM " + schema + ".sale WHERE sale_public_id = ?",
                String.class, salePublicId);
        if (status.isEmpty()) {
            throw new IllegalArgumentException("Unknown bill: " + salePublicId);
        }
        if (!"COMPLETED".equals(status.get(0))) {
            throw new IllegalStateException("Bill " + salePublicId + " is not a completed sale.");
        }
    }

    /**
     * The QUARANTINE location V3 seeds for every pharmacy tenant. If a tenant
     * somehow lacks one, quarantined returns land at the counter with a warning
     * in the log rather than failing the refund — the customer is standing there.
     */
    private String quarantineLocationId(String schema, String fallback) {
        List<String> rows = jdbcTemplate.queryForList(
                "SELECT location_id FROM " + schema + ".stock_location " +
                "WHERE location_kind = 'QUARANTINE' AND active LIMIT 1",
                String.class);
        if (rows.isEmpty()) {
            log.warn("pharmacy_quarantine_location_missing schema={} — restocking instead", schema);
            return fallback;
        }
        return rows.get(0);
    }

    private void announce(String returnPublicId, String salePublicId, long refund,
                          PaymentMode mode, String actor) {
        Map<String, Object> payload = new HashMap<>();
        payload.put("returnPublicId", returnPublicId);
        payload.put("salePublicId", salePublicId);
        payload.put("refundPaise", refund);
        payload.put("refundMode", mode.name());
        eventPublisher.publish(DomainEvent
                .of(ReturnsEvents.CUSTOMER_RETURN_POSTED, "CustomerReturn", returnPublicId, payload)
                .withActor(actor));
    }

    private static String trimToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }
}
