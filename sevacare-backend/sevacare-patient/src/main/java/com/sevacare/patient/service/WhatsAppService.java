package com.sevacare.patient.service;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/**
 * Durable WhatsApp delivery for prescriptions, booking confirmations and
 * follow-up reminders.
 *
 * <p>Enqueueing is the only thing callers do, and it always happens inside the
 * caller's transaction — a message can never survive a rolled-back booking, and
 * a booking can never fail because WhatsApp was down. Delivery is a separate
 * concern handled by {@link #drainOutbox()}.
 *
 * <p>When no provider credentials are configured the rows still accumulate with
 * a {@code wa.me} deep link, so a hospital can adopt WhatsApp later (or send
 * manually) without losing the backlog.
 */
@Service
public class WhatsAppService {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppService.class);

    /** Delivery windows: a reminder queued today for a date weeks away goes out at 9am IST that morning. */
    private static final int REMINDER_HOUR = 9;
    private static final int MAX_ATTEMPTS = 5;
    private static final int BATCH_SIZE = 25;

    public static final String TYPE_PRESCRIPTION = "PRESCRIPTION";
    public static final String TYPE_APPOINTMENT_CONFIRMED = "APPOINTMENT_CONFIRMED";
    public static final String TYPE_FOLLOW_UP = "FOLLOW_UP_REMINDER";

    private final JdbcTemplate jdbc;
    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @Value("${sevacare.whatsapp.enabled:true}")
    private boolean enabled;

    @Value("${sevacare.whatsapp.api-base:https://graph.facebook.com/v20.0}")
    private String apiBase;

    @Value("${sevacare.whatsapp.phone-number-id:}")
    private String phoneNumberId;

    @Value("${sevacare.whatsapp.access-token:}")
    private String accessToken;

    @Value("${sevacare.whatsapp.country-code:91}")
    private String countryCode;

    public WhatsAppService(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    private boolean providerConfigured() {
        return !phoneNumberId.isBlank() && !accessToken.isBlank();
    }

    // ── Enqueue ─────────────────────────────────────────────────────────────

    /**
     * Queues a message for immediate delivery. Never throws: a failure to queue
     * a courtesy message must not fail the consult or booking that triggered it.
     */
    public void enqueue(String tenantPublicId, String toMobile, String messageType,
                        String referenceId, String body) {
        enqueueAt(tenantPublicId, toMobile, messageType, referenceId, body, LocalDateTime.now());
    }

    /** Queues a message to be delivered no earlier than {@code deliverAt}. */
    public void enqueueAt(String tenantPublicId, String toMobile, String messageType,
                          String referenceId, String body, LocalDateTime deliverAt) {
        if (!enabled) {
            return;
        }
        String normalized = normalizeMobile(toMobile);
        if (normalized == null || referenceId == null || body == null || body.isBlank()) {
            return;
        }
        try {
            jdbc.update(
                    "INSERT INTO public.whatsapp_outbox " +
                    "(tenant_public_id, to_mobile, message_type, reference_id, body, wa_link, status, scheduled_at) " +
                    "VALUES (?, ?, ?, ?, ?, ?, 'PENDING', ?) " +
                    "ON CONFLICT (tenant_public_id, message_type, reference_id) DO NOTHING",
                    tenantPublicId, normalized, messageType, referenceId, body,
                    waLink(normalized, body), deliverAt
            );
        } catch (Exception e) {
            log.warn("whatsapp_enqueue_failed tenant={} type={} ref={} reason={}",
                    tenantPublicId, messageType, referenceId, e.getMessage());
        }
    }

    /** 9am on the morning of the follow-up date, or now if that moment already passed. */
    public static LocalDateTime reminderTimeFor(java.time.LocalDate date) {
        LocalDateTime at = date.atTime(REMINDER_HOUR, 0);
        return at.isBefore(LocalDateTime.now()) ? LocalDateTime.now() : at;
    }

    // ── Message bodies ──────────────────────────────────────────────────────

    public static String prescriptionBody(String hospitalName, String patientName, String doctorName,
                                          String prescriptionPublicId, List<String> medicineLines,
                                          String notes, Integer followUpDays) {
        StringBuilder sb = new StringBuilder();
        sb.append("*").append(safe(hospitalName, "SevaCare")).append("*\n");
        sb.append("Prescription ").append(prescriptionPublicId).append("\n\n");
        sb.append("Hello ").append(safe(patientName, "there")).append(",\n");
        sb.append("Dr. ").append(safe(doctorName, "your doctor")).append(" has issued your prescription.\n");
        if (medicineLines != null && !medicineLines.isEmpty()) {
            sb.append("\n*Medicines*\n");
            for (int i = 0; i < medicineLines.size(); i++) {
                sb.append(i + 1).append(". ").append(medicineLines.get(i)).append("\n");
            }
        }
        if (notes != null && !notes.isBlank()) {
            sb.append("\n*Doctor's notes*\n").append(notes.trim()).append("\n");
        }
        if (followUpDays != null && followUpDays > 0) {
            sb.append("\nFollow-up suggested in ").append(followUpDays).append(" days.\n");
        }
        sb.append("\nGet well soon. Reply to this message if you have questions.");
        return sb.toString();
    }

    public static String appointmentConfirmedBody(String hospitalName, String patientName, String doctorName,
                                                  Integer tokenNumber, String tokenSession, String slot) {
        StringBuilder sb = new StringBuilder();
        sb.append("*").append(safe(hospitalName, "SevaCare")).append("*\n");
        sb.append("Appointment confirmed\n\n");
        sb.append("Hello ").append(safe(patientName, "there")).append(",\n");
        sb.append("Your appointment with Dr. ").append(safe(doctorName, "your doctor")).append(" is booked.\n\n");
        if (tokenNumber != null) {
            sb.append("*Token #").append(tokenNumber).append("*");
            if (tokenSession != null && !tokenSession.isBlank()) {
                sb.append(" · ").append(tokenSession);
            }
            sb.append("\n");
        }
        if (slot != null && !slot.isBlank()) {
            sb.append("When: ").append(slot).append("\n");
        }
        sb.append("\nPlease show this message at the reception desk on your visit.");
        return sb.toString();
    }

    public static String followUpBody(String hospitalName, String patientName, String doctorName, String onDate) {
        return "*" + safe(hospitalName, "SevaCare") + "*\n"
                + "Follow-up reminder\n\n"
                + "Hello " + safe(patientName, "there") + ",\n"
                + "Dr. " + safe(doctorName, "your doctor") + " advised a follow-up visit around " + onDate + ".\n\n"
                + "Reply to this message or call the hospital to book your slot.";
    }

    // ── Delivery ────────────────────────────────────────────────────────────

    /**
     * Sends every message whose delivery time has arrived. Rows are claimed by an
     * atomic status flip guarded with {@code FOR UPDATE SKIP LOCKED}, so several
     * Cloud Run instances can drain the same outbox concurrently without sending
     * anything twice — and no transaction is held open across the provider call.
     */
    @Scheduled(fixedDelayString = "${sevacare.whatsapp.drain-interval-ms:60000}", initialDelay = 90_000)
    public void drainOutbox() {
        if (!enabled) {
            return;
        }
        List<OutboxRow> due;
        try {
            if (!providerConfigured()) {
                // Park due rows instead of retrying every minute forever. The body and
                // the wa.me link stay on the row, so a hospital that adopts WhatsApp
                // later can still see (and replay) everything that was queued.
                int parked = jdbc.update(
                        "UPDATE public.whatsapp_outbox SET status = 'NO_PROVIDER', last_error = ? " +
                        "WHERE status = 'PENDING' AND scheduled_at <= CURRENT_TIMESTAMP",
                        "WhatsApp provider credentials are not configured");
                if (parked > 0) {
                    log.info("whatsapp_drain_skipped count={} reason=no_provider_configured", parked);
                }
                return;
            }

            // An instance that dies mid-batch would strand its rows in SENDING; the
            // claim stamps scheduled_at, so anything still SENDING 15 minutes later
            // goes back on the queue.
            jdbc.update("UPDATE public.whatsapp_outbox SET status = 'PENDING' " +
                    "WHERE status = 'SENDING' AND scheduled_at < CURRENT_TIMESTAMP - INTERVAL '15 minutes'");

            due = jdbc.query(
                    "UPDATE public.whatsapp_outbox SET status = 'SENDING', attempts = attempts + 1, " +
                    "scheduled_at = CURRENT_TIMESTAMP " +
                    "WHERE id IN (SELECT id FROM public.whatsapp_outbox " +
                    "             WHERE status = 'PENDING' AND scheduled_at <= CURRENT_TIMESTAMP AND attempts < ? " +
                    "             ORDER BY scheduled_at LIMIT ? FOR UPDATE SKIP LOCKED) " +
                    "RETURNING id, tenant_public_id, to_mobile, message_type, body, attempts",
                    (rs, i) -> new OutboxRow(rs.getLong("id"), rs.getString("tenant_public_id"),
                            rs.getString("to_mobile"), rs.getString("message_type"),
                            rs.getString("body"), rs.getInt("attempts")),
                    MAX_ATTEMPTS, BATCH_SIZE);
        } catch (Exception e) {
            log.warn("whatsapp_drain_query_failed reason={}", e.getMessage());
            return;
        }
        if (due.isEmpty()) {
            return;
        }

        int sent = 0;
        for (OutboxRow row : due) {
            try {
                send(row.toMobile(), row.body());
                jdbc.update("UPDATE public.whatsapp_outbox SET status = 'SENT', sent_at = CURRENT_TIMESTAMP WHERE id = ?",
                        row.id());
                sent++;
            } catch (Exception e) {
                // attempts was already incremented when the row was claimed.
                String status = row.attempts() >= MAX_ATTEMPTS ? "FAILED" : "PENDING";
                jdbc.update("UPDATE public.whatsapp_outbox SET status = ?, last_error = ?, " +
                        // Growing backoff so a provider outage doesn't burn the attempt budget in five minutes.
                        "scheduled_at = CURRENT_TIMESTAMP + (? * INTERVAL '5 minutes') WHERE id = ?",
                        status, truncate(e.getMessage()), row.attempts(), row.id());
                log.warn("whatsapp_send_failed id={} type={} attempt={} reason={}",
                        row.id(), row.messageType(), row.attempts(), e.getMessage());
            }
        }
        if (sent > 0) {
            log.info("whatsapp_drain_sent count={}", sent);
        }
    }

    private void send(String toMobile, String body) throws Exception {
        String payload = "{\"messaging_product\":\"whatsapp\",\"recipient_type\":\"individual\","
                + "\"to\":\"" + toMobile + "\",\"type\":\"text\","
                + "\"text\":{\"preview_url\":false,\"body\":\"" + jsonEscape(body) + "\"}}";

        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiBase + "/" + phoneNumberId + "/messages"))
                .timeout(Duration.ofSeconds(10))
                .header("Authorization", "Bearer " + accessToken)
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(payload, StandardCharsets.UTF_8))
                .build();

        HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("provider returned HTTP " + response.statusCode() + ": " + truncate(response.body()));
        }
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    /** Strips separators and prepends the country code when a bare 10-digit number is given. */
    String normalizeMobile(String raw) {
        if (raw == null) {
            return null;
        }
        String digits = raw.replaceAll("\\D", "");
        if (digits.length() == 10) {
            digits = countryCode + digits;
        }
        return digits.length() >= 11 && digits.length() <= 15 ? digits : null;
    }

    private String waLink(String normalizedMobile, String body) {
        return "https://wa.me/" + normalizedMobile + "?text="
                + URLEncoder.encode(body, StandardCharsets.UTF_8);
    }

    private static String jsonEscape(String s) {
        StringBuilder sb = new StringBuilder(s.length() + 16);
        for (char c : s.toCharArray()) {
            switch (c) {
                case '"'  -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        return sb.toString();
    }

    private static String truncate(String s) {
        if (s == null) return null;
        return s.length() <= 480 ? s : s.substring(0, 480);
    }

    private static String safe(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    private record OutboxRow(long id, String tenantPublicId, String toMobile, String messageType,
                             String body, int attempts) {
    }
}
