package com.sevacare.pharmacy.billing.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.pharmacy.billing.spi.CreditOutstanding;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The khata — who owes the store money, and the repayments that settle it.
 *
 * <p>A CREDIT sale already carries the debt (the bill's total against the
 * customer's mobile); this service adds the other half of the ledger, the
 * {@code credit_payment} rows, and derives outstanding as
 * <em>credit sales − refunds on those sales − payments</em>. Nothing stores a
 * running balance: the documents are the balance, exactly as the stock ledger
 * works for stock.
 */
@Service
public class CreditService {

    private static final Logger log = LoggerFactory.getLogger(CreditService.class);

    private final JdbcTemplate jdbcTemplate;

    public CreditService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    private static final RowMapper<CreditOutstanding> MAPPER = (rs, i) -> {
        long credit = rs.getLong("credit");
        long refunded = rs.getLong("refunded");
        long paid = rs.getLong("paid");
        return new CreditOutstanding(
                rs.getString("customer_mobile"),
                rs.getString("customer_name"),
                credit, refunded, paid,
                credit - refunded - paid,
                rs.getTimestamp("last_credit_at") == null ? null : rs.getTimestamp("last_credit_at").toInstant());
    };

    private String outstandingSql(String schema, String mobileFilter) {
        return "WITH credit_sales AS (" +
               "  SELECT customer_mobile, SUM(total_paise) AS credit, MAX(sold_at) AS last_credit_at " +
               "  FROM " + schema + ".sale " +
               "  WHERE payment_mode = 'CREDIT' AND status = 'COMPLETED' AND customer_mobile IS NOT NULL " +
               mobileFilter +
               "  GROUP BY customer_mobile), " +
               "refunds AS (" +
               "  SELECT s.customer_mobile, SUM(r.refund_paise) AS refunded " +
               "  FROM " + schema + ".customer_return r " +
               "  JOIN " + schema + ".sale s ON s.sale_public_id = r.sale_public_id " +
               "  WHERE s.payment_mode = 'CREDIT' AND s.status = 'COMPLETED' AND s.customer_mobile IS NOT NULL " +
               "  GROUP BY s.customer_mobile), " +
               "payments AS (" +
               "  SELECT customer_mobile, SUM(amount_paise) AS paid " +
               "  FROM " + schema + ".credit_payment GROUP BY customer_mobile) " +
               "SELECT cs.customer_mobile, " +
               "       (SELECT s2.customer_name FROM " + schema + ".sale s2 " +
               "        WHERE s2.customer_mobile = cs.customer_mobile AND s2.customer_name IS NOT NULL " +
               "        ORDER BY s2.sold_at DESC LIMIT 1) AS customer_name, " +
               "       cs.credit, COALESCE(rf.refunded, 0) AS refunded, COALESCE(p.paid, 0) AS paid, " +
               "       cs.last_credit_at " +
               "FROM credit_sales cs " +
               "LEFT JOIN refunds rf ON rf.customer_mobile = cs.customer_mobile " +
               "LEFT JOIN payments p ON p.customer_mobile = cs.customer_mobile " +
               "ORDER BY (cs.credit - COALESCE(rf.refunded, 0) - COALESCE(p.paid, 0)) DESC";
    }

    /** Every customer who still owes something, largest dues first. */
    @Transactional(readOnly = true)
    public List<CreditOutstanding> outstanding() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbcTemplate.query(outstandingSql(schema, ""), MAPPER).stream()
                .filter(c -> c.outstandingPaise() > 0)
                .toList();
    }

    /** One customer's position, for the counter — null when they have no credit history. */
    @Transactional(readOnly = true)
    public CreditOutstanding outstandingFor(String customerMobile) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        List<CreditOutstanding> rows = jdbcTemplate.query(
                outstandingSql(schema, " AND customer_mobile = ? "), MAPPER, customerMobile);
        return rows.isEmpty() ? null : rows.get(0);
    }

    /**
     * Records a repayment. Refuses more than is owed — money above the dues is
     * a typo at the counter, not a tip, and accepting it would leave a negative
     * balance nobody can explain to the customer later.
     */
    @Transactional
    public CreditOutstanding recordPayment(String customerMobile, long amountPaise, String paidVia,
                                           String note, String actor) {
        if (amountPaise <= 0) {
            throw new IllegalArgumentException("A payment needs a positive amount");
        }
        String via = paidVia == null ? "CASH" : paidVia.toUpperCase();
        if (!via.equals("CASH") && !via.equals("UPI") && !via.equals("CARD")) {
            throw new IllegalArgumentException("Payment must arrive as CASH, UPI or CARD");
        }
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        String tenantPublicId = TenantSchemas.requireTenantId(TenantContext.tenantPublicId());

        CreditOutstanding current = outstandingFor(customerMobile);
        long owed = current == null ? 0 : current.outstandingPaise();
        if (amountPaise > owed) {
            throw new IllegalArgumentException(
                    "This customer owes " + rupees(owed) + "; cannot record a payment of " + rupees(amountPaise) + ".");
        }

        Long seq = jdbcTemplate.queryForObject(
                "SELECT nextval('" + schema + ".credit_payment_public_id_seq')", Long.class);
        String paymentPublicId = "PAY-" + String.format("%06d", seq);

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".credit_payment " +
                "(payment_public_id, tenant_public_id, customer_mobile, amount_paise, paid_via, note, actor) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                paymentPublicId, tenantPublicId, customerMobile, amountPaise, via,
                note == null || note.isBlank() ? null : note.trim(), actor);

        log.info("pharmacy_credit_payment payment={} mobile={} amount_paise={} via={}",
                paymentPublicId, customerMobile, amountPaise, via);
        return outstandingFor(customerMobile);
    }

    private static String rupees(long paise) {
        return "Rs " + String.format("%.2f", paise / 100.0);
    }
}
