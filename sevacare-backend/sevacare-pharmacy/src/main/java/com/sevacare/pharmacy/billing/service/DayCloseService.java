package com.sevacare.pharmacy.billing.service;

import java.time.LocalDate;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.billing.spi.DaySummary;
import com.sevacare.pharmacy.billing.spi.MoneyView;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The owner's Money view and the day-close ritual. Closing a day is counting
 * the drawer and writing down the difference — a statement, not a lock. A sale
 * rung after the close still exists and still tells the truth; tomorrow's
 * variance carries the story. What closing does guarantee is that the counted
 * number and the expected number of that moment are recorded together, signed
 * by whoever counted.
 */
@Service
public class DayCloseService {

    private static final Logger log = LoggerFactory.getLogger(DayCloseService.class);

    private final JdbcTemplate jdbcTemplate;
    private final SaleQueryService saleQueryService;

    public DayCloseService(JdbcTemplate jdbcTemplate, SaleQueryService saleQueryService) {
        this.jdbcTemplate = jdbcTemplate;
        this.saleQueryService = saleQueryService;
    }

    @Transactional(readOnly = true)
    public MoneyView moneyView(LocalDate date) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        DaySummary summary = saleQueryService.daySummary(date);

        // Cost of goods for the day, at the batch's own purchase cost — the number
        // GRN's scheme-adjustment made honest. Lines whose batch never got a cost
        // are counted separately, not silently zeroed.
        CostRow cost = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(CASE WHEN b.purchase_price_paise IS NOT NULL " +
                "                    THEN l.qty_base_units * b.purchase_price_paise ELSE 0 END), 0) AS cost, " +
                "       COUNT(*) FILTER (WHERE b.purchase_price_paise IS NULL) AS unknown_lines " +
                "FROM " + schema + ".sale_line l " +
                "JOIN " + schema + ".sale s ON s.sale_public_id = l.sale_public_id " +
                "LEFT JOIN " + schema + ".batch b ON b.batch_public_id = l.batch_public_id " +
                "WHERE s.sale_date = ? AND s.status = 'COMPLETED'",
                (rs, i) -> new CostRow(rs.getLong("cost"), rs.getInt("unknown_lines")),
                java.sql.Date.valueOf(date));

        RefundRow refunds = jdbcTemplate.queryForObject(
                "SELECT COALESCE(SUM(refund_paise), 0) AS total, " +
                "       COALESCE(SUM(refund_paise) FILTER (WHERE refund_mode = 'CASH'), 0) AS cash " +
                "FROM " + schema + ".customer_return WHERE return_date = ?",
                (rs, i) -> new RefundRow(rs.getLong("total"), rs.getLong("cash")),
                java.sql.Date.valueOf(date));

        long cashSales = summary.byPaymentMode().stream()
                .filter(t -> t.paymentMode() == com.sevacare.pharmacy.billing.spi.PaymentMode.CASH)
                .mapToLong(DaySummary.PaymentTotal::totalPaise)
                .sum();
        long expectedCash = cashSales - refunds.cash();
        long margin = summary.totalPaise() - refunds.total() - cost.cost();

        return new MoneyView(summary, cost.cost(), margin, cost.unknownLines(),
                refunds.total(), refunds.cash(), expectedCash, findClose(schema, date));
    }

    @Transactional
    public MoneyView close(LocalDate date, long countedCashPaise, String note, String actor) {
        if (countedCashPaise < 0) {
            throw new IllegalArgumentException("Counted cash cannot be negative");
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());

        if (findClose(schema, date) != null) {
            throw new IllegalStateException("The day " + date + " is already closed.");
        }

        MoneyView view = moneyView(date);
        long variance = countedCashPaise - view.expectedCashPaise();

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".day_close " +
                "(close_date, tenant_public_id, sale_count, total_paise, expected_cash_paise, " +
                " counted_cash_paise, variance_paise, note, closed_by) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                java.sql.Date.valueOf(date), tenantPublicId, view.summary().saleCount(),
                view.summary().totalPaise(), view.expectedCashPaise(), countedCashPaise, variance,
                trimToNull(note), actor);

        log.info("pharmacy_day_closed date={} expected_paise={} counted_paise={} variance_paise={}",
                date, view.expectedCashPaise(), countedCashPaise, variance);

        return moneyView(date);
    }

    private MoneyView.DayCloseInfo findClose(String schema, LocalDate date) {
        List<MoneyView.DayCloseInfo> rows = jdbcTemplate.query(
                "SELECT close_date, expected_cash_paise, counted_cash_paise, variance_paise, " +
                "       note, closed_by, closed_at " +
                "FROM " + schema + ".day_close WHERE close_date = ?",
                (rs, i) -> new MoneyView.DayCloseInfo(
                        rs.getDate("close_date").toLocalDate(),
                        rs.getLong("expected_cash_paise"),
                        rs.getLong("counted_cash_paise"),
                        rs.getLong("variance_paise"),
                        rs.getString("note"),
                        rs.getString("closed_by"),
                        rs.getTimestamp("closed_at").toInstant()),
                java.sql.Date.valueOf(date));
        return rows.isEmpty() ? null : rows.get(0);
    }

    private static String trimToNull(String s) {
        if (s == null) {
            return null;
        }
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private record CostRow(long cost, int unknownLines) {
    }

    private record RefundRow(long total, long cash) {
    }
}
