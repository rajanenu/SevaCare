package com.sevacare.pharmacy.billing.service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.billing.spi.CustomerHistoryPage;
import com.sevacare.pharmacy.billing.spi.DailyTotal;
import com.sevacare.pharmacy.billing.spi.DaySummary;
import com.sevacare.pharmacy.billing.spi.GstSlabTotal;
import com.sevacare.pharmacy.billing.spi.PaymentMode;
import com.sevacare.pharmacy.billing.spi.SaleReceipt;
import com.sevacare.pharmacy.billing.spi.SalesRegisterLine;
import com.sevacare.pharmacy.billing.spi.SaleSummary;
import com.sevacare.pharmacy.billing.spi.TopMedicine;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Reads over completed sales — the day-close, the recent-bills list, and one bill
 * fetched back for reprint. Read-only and off the write path, so a manager pulling
 * the day's numbers never contends with the counter making the next sale.
 */
@Service
public class SaleQueryService {

    private static final int MAX_RECENT = 50;

    private final JdbcTemplate jdbcTemplate;

    public SaleQueryService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public DaySummary daySummary(LocalDate date) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        List<DaySummary.PaymentTotal> byMode = jdbcTemplate.query(
                "SELECT payment_mode, COUNT(*) AS n, COALESCE(SUM(total_paise), 0) AS total " +
                "FROM " + schema + ".sale WHERE sale_date = ? AND status = 'COMPLETED' " +
                "GROUP BY payment_mode ORDER BY payment_mode",
                (rs, i) -> new DaySummary.PaymentTotal(
                        PaymentMode.parse(rs.getString("payment_mode")),
                        rs.getInt("n"),
                        rs.getLong("total")),
                java.sql.Date.valueOf(date));

        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) AS n, " +
                "       COALESCE(SUM(gross_paise), 0) AS gross, " +
                "       COALESCE(SUM(discount_paise), 0) AS discount, " +
                "       COALESCE(SUM(taxable_paise), 0) AS taxable, " +
                "       COALESCE(SUM(gst_paise), 0) AS gst, " +
                "       COALESCE(SUM(total_paise), 0) AS total " +
                "FROM " + schema + ".sale WHERE sale_date = ? AND status = 'COMPLETED'",
                (rs, i) -> new DaySummary(
                        date, rs.getInt("n"),
                        rs.getLong("gross"), rs.getLong("discount"), rs.getLong("taxable"),
                        rs.getLong("gst"), rs.getLong("total"), byMode),
                java.sql.Date.valueOf(date));
    }

    private static final int MAX_RANGE = 500;

    private static final org.springframework.jdbc.core.RowMapper<SaleSummary> SALE_SUMMARY_MAPPER = (rs, i) -> new SaleSummary(
            rs.getString("sale_public_id"),
            rs.getString("invoice_no"),
            rs.getTimestamp("sold_at").toInstant(),
            rs.getString("customer_name"),
            rs.getString("customer_mobile"),
            PaymentMode.parse(rs.getString("payment_mode")),
            rs.getInt("items"),
            rs.getLong("total_paise"),
            rs.getString("status"));

    /**
     * The same shape as {@link #daySummary}, over an arbitrary range — the
     * Dashboard tab's Week/Month/Custom filters. {@code saleDate} on the
     * result is the range's start; the caller already knows the end it asked
     * for.
     */
    @Transactional(readOnly = true)
    public DaySummary rangeSummary(LocalDate from, LocalDate to) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        List<DaySummary.PaymentTotal> byMode = jdbcTemplate.query(
                "SELECT payment_mode, COUNT(*) AS n, COALESCE(SUM(total_paise), 0) AS total " +
                "FROM " + schema + ".sale WHERE sale_date BETWEEN ? AND ? AND status = 'COMPLETED' " +
                "GROUP BY payment_mode ORDER BY payment_mode",
                (rs, i) -> new DaySummary.PaymentTotal(
                        PaymentMode.parse(rs.getString("payment_mode")),
                        rs.getInt("n"),
                        rs.getLong("total")),
                java.sql.Date.valueOf(from), java.sql.Date.valueOf(to));

        return jdbcTemplate.queryForObject(
                "SELECT COUNT(*) AS n, " +
                "       COALESCE(SUM(gross_paise), 0) AS gross, " +
                "       COALESCE(SUM(discount_paise), 0) AS discount, " +
                "       COALESCE(SUM(taxable_paise), 0) AS taxable, " +
                "       COALESCE(SUM(gst_paise), 0) AS gst, " +
                "       COALESCE(SUM(total_paise), 0) AS total " +
                "FROM " + schema + ".sale WHERE sale_date BETWEEN ? AND ? AND status = 'COMPLETED'",
                (rs, i) -> new DaySummary(
                        from, rs.getInt("n"),
                        rs.getLong("gross"), rs.getLong("discount"), rs.getLong("taxable"),
                        rs.getLong("gst"), rs.getLong("total"), byMode),
                java.sql.Date.valueOf(from), java.sql.Date.valueOf(to));
    }

    @Transactional(readOnly = true)
    public List<SaleSummary> recentSales(int limit) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        int capped = Math.min(Math.max(limit, 1), MAX_RECENT);
        return jdbcTemplate.query(
                "SELECT s.sale_public_id, s.invoice_no, s.sold_at, s.customer_name, s.customer_mobile, " +
                "       s.payment_mode, s.status, s.total_paise, " +
                "       (SELECT COUNT(*) FROM " + schema + ".sale_line l " +
                "                       WHERE l.sale_public_id = s.sale_public_id) AS items " +
                "FROM " + schema + ".sale s WHERE s.status = 'COMPLETED' " +
                "ORDER BY s.sold_at DESC LIMIT ?",
                SALE_SUMMARY_MAPPER,
                capped);
    }

    /**
     * The invoices table's data source — every bill (including voided ones, so
     * a void is visible, not a disappearance) in a date range, sortable by
     * when it was rung up or by how much it was for.
     */
    @Transactional(readOnly = true)
    public List<SaleSummary> salesInRange(LocalDate from, LocalDate to, String sortBy, int limit) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        int capped = Math.min(Math.max(limit, 1), MAX_RANGE);
        String orderBy = "amount".equalsIgnoreCase(sortBy) ? "s.total_paise DESC" : "s.sold_at DESC";
        return jdbcTemplate.query(
                "SELECT s.sale_public_id, s.invoice_no, s.sold_at, s.customer_name, s.customer_mobile, " +
                "       s.payment_mode, s.status, s.total_paise, " +
                "       (SELECT COUNT(*) FROM " + schema + ".sale_line l " +
                "                       WHERE l.sale_public_id = s.sale_public_id) AS items " +
                "FROM " + schema + ".sale s WHERE s.sale_date BETWEEN ? AND ? " +
                "ORDER BY " + orderBy + " LIMIT ?",
                SALE_SUMMARY_MAPPER,
                java.sql.Date.valueOf(from), java.sql.Date.valueOf(to), capped);
    }

    /** The customer's most recent completed sale, for a one-tap "same as last time" rebill. */
    @Transactional(readOnly = true)
    public Optional<SaleReceipt> lastSaleForMobile(String customerMobile) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        List<String> ids = jdbcTemplate.queryForList(
                "SELECT sale_public_id FROM " + schema + ".sale " +
                "WHERE customer_mobile = ? AND status = 'COMPLETED' ORDER BY sold_at DESC LIMIT 1",
                String.class, customerMobile);
        return ids.isEmpty() ? Optional.empty() : findReceipt(ids.get(0));
    }

    private static final int HISTORY_PAGE_SIZE = 5;
    private static final int MAX_HISTORY_PAGE_SIZE = 50;

    /**
     * A customer's full billing history at this counter, paginated — keyed on
     * mobile alone (the identifier the khata and rebill chip already use; a name
     * is too easily shared or mistyped to match reliably). {@code totalCount} is
     * 0 for a mobile never seen before — the counter's cue to show "New customer"
     * rather than an empty accordion.
     */
    @Transactional(readOnly = true)
    public CustomerHistoryPage customerHistory(String mobile, int page, int size) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        int p = Math.max(page, 0);
        int capped = Math.min(Math.max(size <= 0 ? HISTORY_PAGE_SIZE : size, 1), MAX_HISTORY_PAGE_SIZE);
        int offset = p * capped;

        String mobileTrim = mobile == null ? "" : mobile.trim();
        if (mobileTrim.isEmpty()) {
            return new CustomerHistoryPage(0, p, capped, List.of());
        }

        int total = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".sale s " +
                "WHERE s.customer_mobile = ? AND s.status = 'COMPLETED'",
                Integer.class, mobileTrim);

        List<SaleSummary> sales = total == 0 ? List.of() : jdbcTemplate.query(
                "SELECT s.sale_public_id, s.invoice_no, s.sold_at, s.customer_name, s.customer_mobile, " +
                "       s.payment_mode, s.status, s.total_paise, " +
                "       (SELECT COUNT(*) FROM " + schema + ".sale_line l " +
                "                       WHERE l.sale_public_id = s.sale_public_id) AS items " +
                "FROM " + schema + ".sale s WHERE s.customer_mobile = ? AND s.status = 'COMPLETED' " +
                "ORDER BY s.sold_at DESC LIMIT ? OFFSET ?",
                SALE_SUMMARY_MAPPER, mobileTrim, capped, offset);

        return new CustomerHistoryPage(total, p, capped, sales);
    }

    /** One row per calendar day in the window — the shape of the business, not just today's number. */
    @Transactional(readOnly = true)
    public List<DailyTotal> dailyTotals(LocalDate from, LocalDate to) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbcTemplate.query(
                "SELECT sale_date, COUNT(*) AS n, COALESCE(SUM(total_paise), 0) AS total " +
                "FROM " + schema + ".sale WHERE status = 'COMPLETED' AND sale_date BETWEEN ? AND ? " +
                "GROUP BY sale_date ORDER BY sale_date",
                (rs, i) -> new DailyTotal(
                        rs.getDate("sale_date").toLocalDate(), rs.getLong("total"), rs.getInt("n")),
                java.sql.Date.valueOf(from), java.sql.Date.valueOf(to));
    }

    /**
     * What is selling, over a window — the report the owner reorders from. Ranked
     * by units moved (the reorder decision), carrying revenue and bill count so a
     * high-margin slow mover and a cheap fast mover can be told apart. Ordered by
     * quantity, then revenue, so a tie breaks toward the item that earned more.
     */
    @Transactional(readOnly = true)
    public List<TopMedicine> topMedicines(LocalDate from, LocalDate to, int limit) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        int capped = Math.min(Math.max(limit, 1), 100);
        return jdbcTemplate.query(
                "SELECT l.sku_public_id, s.brand_name, s.dosage_form, " +
                "       SUM(l.qty_base_units) AS qty, " +
                "       SUM(l.gross_paise - l.discount_paise) AS revenue, " +
                "       COUNT(DISTINCT l.sale_public_id) AS bills " +
                "FROM " + schema + ".sale_line l " +
                "JOIN " + schema + ".sale sa ON sa.sale_public_id = l.sale_public_id " +
                "JOIN " + schema + ".medicine_sku s ON s.sku_public_id = l.sku_public_id " +
                "WHERE sa.status = 'COMPLETED' AND sa.sale_date BETWEEN ? AND ? " +
                "GROUP BY l.sku_public_id, s.brand_name, s.dosage_form " +
                "ORDER BY qty DESC, revenue DESC LIMIT " + capped,
                (rs, i) -> new TopMedicine(
                        rs.getString("sku_public_id"),
                        rs.getString("brand_name"),
                        rs.getString("dosage_form"),
                        rs.getLong("qty"),
                        rs.getLong("revenue"),
                        rs.getLong("bills")),
                java.sql.Date.valueOf(from), java.sql.Date.valueOf(to));
    }

    /**
     * The line-level audit trail — every sale line in the window, unaggregated,
     * for a downloadable register (blueprint: "what all medicines were sold").
     * Manual (non-catalog) lines appear too, carrying whatever the pharmacist
     * typed as the item name, since a courier charge still belongs on the money
     * trail even though it isn't a medicine.
     */
    @Transactional(readOnly = true)
    public List<SalesRegisterLine> salesRegister(LocalDate from, LocalDate to) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbcTemplate.query(
                "SELECT sa.sale_date, sa.invoice_no, COALESCE(s.brand_name, l.manual_label) AS item_name, " +
                "       b.batch_no, l.qty_base_units, l.gross_paise, l.gst_paise, " +
                "       (l.gross_paise - l.discount_paise) AS total_paise " +
                "FROM " + schema + ".sale_line l " +
                "JOIN " + schema + ".sale sa ON sa.sale_public_id = l.sale_public_id " +
                "LEFT JOIN " + schema + ".medicine_sku s ON s.sku_public_id = l.sku_public_id " +
                "LEFT JOIN " + schema + ".batch b ON b.batch_public_id = l.batch_public_id " +
                "WHERE sa.status = 'COMPLETED' AND sa.sale_date BETWEEN ? AND ? " +
                "ORDER BY sa.sale_date, sa.invoice_no, l.line_id",
                (rs, i) -> new SalesRegisterLine(
                        rs.getDate("sale_date").toLocalDate(), rs.getString("invoice_no"),
                        rs.getString("item_name"), rs.getString("batch_no"),
                        rs.getInt("qty_base_units"), rs.getLong("gross_paise"), rs.getLong("gst_paise"),
                        rs.getLong("total_paise")),
                java.sql.Date.valueOf(from), java.sql.Date.valueOf(to));
    }

    /**
     * Sales grouped by GST slab over a window — what the accountant asks for at
     * filing time. Voided sales are excluded with the same COMPLETED filter as
     * every other money report, so the report and the register always agree.
     */
    @Transactional(readOnly = true)
    public List<GstSlabTotal> gstSummary(LocalDate from, LocalDate to) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbcTemplate.query(
                "SELECT l.gst_rate_bp, " +
                "       COALESCE(SUM(l.taxable_paise), 0) AS taxable, " +
                "       COALESCE(SUM(l.gst_paise), 0) AS gst, " +
                "       COALESCE(SUM(l.gross_paise - l.discount_paise), 0) AS gross, " +
                "       COUNT(*) AS lines " +
                "FROM " + schema + ".sale_line l " +
                "JOIN " + schema + ".sale sa ON sa.sale_public_id = l.sale_public_id " +
                "WHERE sa.status = 'COMPLETED' AND sa.sale_date BETWEEN ? AND ? " +
                "GROUP BY l.gst_rate_bp ORDER BY l.gst_rate_bp",
                (rs, i) -> new GstSlabTotal(
                        rs.getInt("gst_rate_bp"), rs.getLong("taxable"), rs.getLong("gst"),
                        rs.getLong("gross"), rs.getInt("lines")),
                java.sql.Date.valueOf(from), java.sql.Date.valueOf(to));
    }

    @Transactional(readOnly = true)
    public Optional<SaleReceipt> findReceipt(String salePublicId) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        List<SaleReceipt> heads = jdbcTemplate.query(
                "SELECT sale_public_id, invoice_no, sale_date, sold_at, customer_name, customer_mobile, " +
                "       prescriber_name, payment_mode, gross_paise, discount_paise, taxable_paise, " +
                "       gst_paise, total_paise " +
                "FROM " + schema + ".sale WHERE sale_public_id = ?",
                (rs, i) -> new SaleReceipt(
                        rs.getString("sale_public_id"), rs.getString("invoice_no"),
                        rs.getDate("sale_date").toLocalDate(), rs.getTimestamp("sold_at").toInstant(),
                        rs.getString("customer_name"), rs.getString("customer_mobile"),
                        rs.getString("prescriber_name"), PaymentMode.parse(rs.getString("payment_mode")),
                        rs.getLong("gross_paise"), rs.getLong("discount_paise"), rs.getLong("taxable_paise"),
                        rs.getLong("gst_paise"), rs.getLong("total_paise"),
                        new ArrayList<>(), List.of(), null),
                salePublicId);
        if (heads.isEmpty()) {
            return Optional.empty();
        }
        SaleReceipt head = heads.get(0);

        List<SaleReceipt.Line> lines = jdbcTemplate.query(
                "SELECT l.sku_public_id, COALESCE(s.brand_name, l.manual_label) AS brand_name, " +
                "       l.batch_public_id, b.expiry_date, l.schedule_class, " +
                "       l.qty_base_units, l.mrp_paise, l.gross_paise, l.discount_paise, l.gst_rate_bp, " +
                "       l.taxable_paise, l.gst_paise " +
                "FROM " + schema + ".sale_line l " +
                "LEFT JOIN " + schema + ".medicine_sku s ON s.sku_public_id = l.sku_public_id " +
                "LEFT JOIN " + schema + ".batch b ON b.batch_public_id = l.batch_public_id " +
                "WHERE l.sale_public_id = ? ORDER BY l.line_id",
                (rs, i) -> new SaleReceipt.Line(
                        rs.getString("sku_public_id"), rs.getString("brand_name"),
                        rs.getString("batch_public_id"),
                        rs.getDate("expiry_date") == null ? null : rs.getDate("expiry_date").toLocalDate(),
                        rs.getString("schedule_class"), rs.getInt("qty_base_units"), rs.getLong("mrp_paise"),
                        rs.getLong("gross_paise"), rs.getLong("discount_paise"), rs.getInt("gst_rate_bp"),
                        rs.getLong("taxable_paise"), rs.getLong("gst_paise")),
                salePublicId);

        return Optional.of(new SaleReceipt(
                head.salePublicId(), head.invoiceNo(), head.saleDate(), head.soldAt(),
                head.customerName(), head.customerMobile(), head.prescriberName(), head.paymentMode(),
                head.grossPaise(), head.discountPaise(), head.taxablePaise(), head.gstPaise(),
                head.totalPaise(), lines, List.of(), null));
    }
}
