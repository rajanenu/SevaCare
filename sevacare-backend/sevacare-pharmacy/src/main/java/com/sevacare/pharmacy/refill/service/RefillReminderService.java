package com.sevacare.pharmacy.refill.service;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import com.sevacare.pharmacy.refill.spi.RefillDueItem;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * The refill loop: because this system holds both the prescription counter's
 * sales ledger and the customer's mobile, it can see a purchase rhythm no
 * standalone pharmacy software or EMR can — "this customer buys this SKU every
 * N days and is about to run out" — and turn it into a WhatsApp nudge plus a
 * worklist on the Sell tab.
 *
 * <p>Cadence is counted, never guessed: a (customer, sku) pair qualifies only
 * after purchases on two or more days, and the cycle length is the observed
 * span divided by the intervals ((last − first) / (buys − 1)), accepted only in
 * the 7–120 day band a real refill rhythm lives in.
 *
 * <p>Every step is safe to re-run: the partial unique index on open cycles
 * makes the scan's INSERT idempotent, the WhatsApp outbox dedupes on
 * (tenant, type, reference), and fulfilment is an UPDATE keyed on a newer sale
 * existing. Like the catalog seeder's boot sweep, each tenant is processed in
 * its own try/catch so one broken schema cannot take the sweep down.
 *
 * <p>Same module-boundary note as {@code PharmacyReceiptNotifier}: pharmacy
 * never imports the patient module that owns {@code WhatsAppService}; it
 * inserts into the plain {@code public.whatsapp_outbox} table directly.
 */
@Service
public class RefillReminderService {

    private static final Logger log = LoggerFactory.getLogger(RefillReminderService.class);

    private static final String MESSAGE_TYPE = "REFILL_REMINDER";
    /** Nudge this many days before the projected run-out. */
    private static final int LEAD_DAYS = 3;
    /** A cycle whose due date is longer ago than this was bought elsewhere; let it lapse. */
    private static final int GRACE_DAYS = 14;
    /** How far back sales inform a cadence. */
    private static final int LOOKBACK_DAYS = 240;

    private final JdbcTemplate jdbc;

    @Value("${sevacare.whatsapp.country-code:91}")
    private String countryCode;

    /**
     * Per-instance day guard so the 5-minute internal-jobs tick doesn't re-run
     * the aggregate all day. Losing it on restart is fine — every statement the
     * scan runs is idempotent.
     */
    private final Map<String, LocalDate> scannedOn = new ConcurrentHashMap<>();

    public RefillReminderService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    // ── Daily scan (job context: no TenantContext, schemas passed explicitly) ──

    /** Cron twin of the /internal/jobs entry — Cloud Run may never fire this. */
    @Scheduled(cron = "0 30 8 * * *", zone = "Asia/Kolkata")
    public void scheduledScan() {
        scanAllTenants();
    }

    public void scanAllTenants() {
        List<Map<String, Object>> tenants = jdbc.queryForList(
                "SELECT tenant_public_id, tenant_name, tenant_schema_name FROM public.tenant_registry " +
                "WHERE tenant_status = 'active' AND pharmacy_profile_key IS NOT NULL " +
                "ORDER BY tenant_public_id");
        LocalDate today = LocalDate.now();
        for (Map<String, Object> tenant : tenants) {
            String tenantPublicId = (String) tenant.get("tenant_public_id");
            if (today.equals(scannedOn.get(tenantPublicId))) {
                continue;
            }
            try {
                scanTenant(tenantPublicId,
                        (String) tenant.get("tenant_schema_name"),
                        (String) tenant.get("tenant_name"));
                scannedOn.put(tenantPublicId, today);
            } catch (Exception e) {
                log.error("refill_scan_failed tenantPublicId={}", tenantPublicId, e);
            }
        }
    }

    private void scanTenant(String tenantPublicId, String tenantSchema, String tenantName) {
        String schema = TenantSchemas.require(tenantSchema);

        // 1. Close every open cycle the customer has already answered with a purchase.
        int fulfilled = jdbc.update(
                "UPDATE " + schema + ".refill_reminder r " +
                "SET status = 'FULFILLED', resolved_at = CURRENT_TIMESTAMP " +
                "WHERE r.status IN ('DUE', 'NOTIFIED') AND EXISTS (" +
                "  SELECT 1 FROM " + schema + ".sale s " +
                "  JOIN " + schema + ".sale_line l ON l.sale_public_id = s.sale_public_id " +
                "  WHERE s.status = 'COMPLETED' AND s.customer_mobile = r.customer_mobile " +
                "    AND l.sku_public_id = r.sku_public_id AND s.sale_date > r.last_sale_date)");

        // 2. Open a cycle for every rhythm whose projected run-out is near. The
        //    partial unique index on open (customer, sku) makes re-runs no-ops.
        int opened = jdbc.update(
                "INSERT INTO " + schema + ".refill_reminder " +
                "  (tenant_public_id, customer_mobile, customer_name, sku_public_id, brand_name, " +
                "   last_sale_date, cadence_days, due_date, status) " +
                "SELECT ?, c.customer_mobile, c.customer_name, c.sku_public_id, k.brand_name, " +
                "       c.last_date, c.cadence_days, c.last_date + c.cadence_days, 'DUE' " +
                "FROM (" +
                "  SELECT s.customer_mobile, " +
                "         max(s.customer_name) AS customer_name, " +
                "         l.sku_public_id, " +
                "         min(s.sale_date) AS first_date, " +
                "         max(s.sale_date) AS last_date, " +
                // ::int matters: count() is bigint, and date + bigint has no operator.
                "         ((max(s.sale_date) - min(s.sale_date)) / (count(DISTINCT s.sale_date) - 1))::int AS cadence_days " +
                "  FROM " + schema + ".sale s " +
                "  JOIN " + schema + ".sale_line l ON l.sale_public_id = s.sale_public_id " +
                "  WHERE s.status = 'COMPLETED' " +
                "    AND s.customer_mobile IS NOT NULL AND s.customer_mobile <> '' " +
                "    AND s.sale_date >= CURRENT_DATE - " + LOOKBACK_DAYS + " " +
                "  GROUP BY s.customer_mobile, l.sku_public_id " +
                "  HAVING count(DISTINCT s.sale_date) >= 2" +
                ") c " +
                "JOIN " + schema + ".medicine_sku k ON k.sku_public_id = c.sku_public_id " +
                "WHERE c.cadence_days BETWEEN 7 AND 120 " +
                "  AND (c.last_date + c.cadence_days) " +
                "      BETWEEN CURRENT_DATE - " + GRACE_DAYS + " AND CURRENT_DATE + " + LEAD_DAYS + " " +
                "ON CONFLICT (customer_mobile, sku_public_id) WHERE status IN ('DUE', 'NOTIFIED') DO NOTHING",
                tenantPublicId);

        int notified = notifyDue(tenantPublicId, schema, tenantName);
        if (opened > 0 || notified > 0 || fulfilled > 0) {
            log.info("refill_scan tenantPublicId={} fulfilled={} opened={} notified={}",
                    tenantPublicId, fulfilled, opened, notified);
        }
    }

    /**
     * Queues the WhatsApp nudge for every DUE cycle and flips it to NOTIFIED.
     * A crash between the two statements just re-runs later: the outbox insert
     * dedupes on reference "refill-{id}", so at-least-once becomes exactly-one
     * message.
     */
    private int notifyDue(String tenantPublicId, String schema, String tenantName) {
        List<Map<String, Object>> due = jdbc.queryForList(
                "SELECT id, customer_mobile, customer_name, brand_name, due_date " +
                "FROM " + schema + ".refill_reminder " +
                "WHERE status = 'DUE' AND due_date <= CURRENT_DATE + " + LEAD_DAYS + " " +
                "ORDER BY due_date, id LIMIT 200");
        int sent = 0;
        for (Map<String, Object> row : due) {
            long id = ((Number) row.get("id")).longValue();
            String mobile = normalizeMobile((String) row.get("customer_mobile"));
            if (mobile != null) {
                String body = refillBody(tenantName,
                        (String) row.get("customer_name"),
                        (String) row.get("brand_name"));
                try {
                    jdbc.update(
                            "INSERT INTO public.whatsapp_outbox " +
                            "(tenant_public_id, to_mobile, message_type, reference_id, body, wa_link, status, scheduled_at) " +
                            "VALUES (?, ?, ?, ?, ?, ?, 'PENDING', CURRENT_TIMESTAMP) " +
                            "ON CONFLICT (tenant_public_id, message_type, reference_id) DO NOTHING",
                            tenantPublicId, mobile, MESSAGE_TYPE, "refill-" + id, body, waLink(mobile, body));
                } catch (Exception e) {
                    log.warn("refill_whatsapp_enqueue_failed tenantPublicId={} reminderId={} reason={}",
                            tenantPublicId, id, e.getMessage());
                    continue; // stay DUE, retry on the next scan
                }
            }
            // No usable mobile still flips to NOTIFIED: the worklist keeps the row
            // visible either way, and retrying an unsendable number daily is noise.
            jdbc.update("UPDATE " + schema + ".refill_reminder " +
                    "SET status = 'NOTIFIED', notified_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'DUE'", id);
            sent++;
        }
        return sent;
    }

    // ── Counter worklist (request context: schema from TenantContext) ────────

    /** Open cycles due within a week — the Sell tab's "Due for refill" list. */
    public List<RefillDueItem> listDue() {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbc.query(
                "SELECT id, customer_mobile, customer_name, sku_public_id, brand_name, " +
                "       last_sale_date, cadence_days, due_date, status, notified_at " +
                "FROM " + schema + ".refill_reminder " +
                "WHERE status IN ('DUE', 'NOTIFIED') AND due_date <= CURRENT_DATE + 7 " +
                "ORDER BY due_date, id LIMIT 300",
                (rs, i) -> new RefillDueItem(
                        rs.getLong("id"),
                        rs.getString("customer_mobile"),
                        rs.getString("customer_name"),
                        rs.getString("sku_public_id"),
                        rs.getString("brand_name"),
                        rs.getObject("last_sale_date", LocalDate.class),
                        rs.getInt("cadence_days"),
                        rs.getObject("due_date", LocalDate.class),
                        rs.getString("status"),
                        rs.getObject("notified_at", java.time.LocalDateTime.class)));
    }

    /** Counter closed the cycle by hand ("they moved away", "doctor changed the brand"). */
    public boolean dismiss(long id) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());
        return jdbc.update(
                "UPDATE " + schema + ".refill_reminder " +
                "SET status = 'DISMISSED', resolved_at = CURRENT_TIMESTAMP " +
                "WHERE id = ? AND status IN ('DUE', 'NOTIFIED')", id) > 0;
    }

    // ── Message plumbing (mirrors PharmacyReceiptNotifier) ───────────────────

    private static String refillBody(String shopName, String customerName, String brandName) {
        String shop = (shopName == null || shopName.isBlank()) ? "Your pharmacy" : shopName;
        String hello = (customerName == null || customerName.isBlank()) ? "there" : customerName;
        return "*" + shop + "*\n"
                + "Refill reminder\n\n"
                + "Hello " + hello + ",\n"
                + "Your *" + brandName + "* may be running low based on your usual purchase.\n\n"
                + "Reply to this message and we'll keep your refill ready, or drop by the store.";
    }

    private String normalizeMobile(String raw) {
        if (raw == null) {
            return null;
        }
        String digits = raw.replaceAll("\\D", "");
        if (digits.length() == 10) {
            digits = countryCode + digits;
        }
        return digits.length() >= 11 && digits.length() <= 15 ? digits : null;
    }

    private static String waLink(String normalizedMobile, String body) {
        return "https://wa.me/" + normalizedMobile + "?text="
                + URLEncoder.encode(body, StandardCharsets.UTF_8);
    }
}
