package com.sevacare.api.service;

import java.util.List;
import java.util.function.Supplier;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

/**
 * Exactly-once execution for the POSTs that must never run twice. A booking or
 * counter-sale retried on a flaky network is a double booking or a double
 * dispense — and the stock ledger would faithfully record both.
 *
 * <p>The client sends a stable {@code Idempotency-Key} for one logical attempt
 * (same key on every retry of that attempt, new key for a new cart/booking).
 * The whole dance is one transaction:
 *
 * <ol>
 * <li>Claim the key with an {@code INSERT}. A retry racing the original blocks
 *     on the primary key until the original commits, then sees the claim.</li>
 * <li>Claimed: run the operation — it joins this transaction, so the claim,
 *     the work, and the stored response commit or roll back <em>together</em>.
 *     A crash leaves nothing: no sale, no claim, and the retry runs fresh.</li>
 * <li>Not claimed: return the stored response verbatim; the retry cannot tell
 *     it wasn't first, and nothing executed twice.</li>
 * </ol>
 *
 * <p>Requests without the header run untouched, so an old client keeps working
 * — it just keeps its old double-submit risk until it upgrades.
 */
@Service
public class IdempotencyService {

    private static final Logger log = LoggerFactory.getLogger(IdempotencyService.class);

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public IdempotencyService(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @Transactional
    public <T> T execute(String tenantPublicId, String idempotencyKey, String endpoint,
                         Class<T> responseType, Supplier<T> operation) {
        if (idempotencyKey == null || idempotencyKey.isBlank()) {
            return operation.get();
        }
        String key = idempotencyKey.trim();
        if (key.length() > 80) {
            throw new IllegalArgumentException("Idempotency-Key must be at most 80 characters");
        }

        int claimed = jdbcTemplate.update(
                "INSERT INTO public.idempotency_key (tenant_public_id, idem_key, endpoint) " +
                        "VALUES (?, ?, ?) ON CONFLICT (tenant_public_id, idem_key) DO NOTHING",
                tenantPublicId, key, endpoint);

        if (claimed == 0) {
            List<Stored> rows = jdbcTemplate.query(
                    "SELECT endpoint, response_json FROM public.idempotency_key " +
                            "WHERE tenant_public_id = ? AND idem_key = ?",
                    (rs, i) -> new Stored(rs.getString(1), rs.getString(2)),
                    tenantPublicId, key);
            Stored stored = rows.isEmpty() ? null : rows.get(0);
            if (stored == null || stored.responseJson() == null) {
                // The original is mid-flight on another connection (or crashed a
                // heartbeat ago and its claim is rolling back). Either way: wait,
                // don't run.
                throw new DuplicateRequestException(
                        "This request is already being processed — please wait a moment.");
            }
            if (!endpoint.equals(stored.endpoint())) {
                throw new IllegalArgumentException(
                        "Idempotency-Key was already used for a different operation");
            }
            log.info("idempotent_replay tenant={} endpoint={} key={}", tenantPublicId, endpoint, key);
            return deserialize(stored.responseJson(), responseType);
        }

        T result = operation.get();
        jdbcTemplate.update(
                "UPDATE public.idempotency_key SET response_json = ? " +
                        "WHERE tenant_public_id = ? AND idem_key = ?",
                serialize(result), tenantPublicId, key);
        return result;
    }

    /** A key outlives any sane retry window by a wide margin; then it is noise. */
    @Scheduled(cron = "0 50 3 * * *", zone = "Asia/Kolkata")
    public void pruneExpired() {
        int pruned = jdbcTemplate.update(
                "DELETE FROM public.idempotency_key WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '48 hours'");
        if (pruned > 0) {
            log.info("idempotency_key_prune rows={}", pruned);
        }
    }

    private record Stored(String endpoint, String responseJson) {
    }

    private String serialize(Object value) {
        try {
            return objectMapper.writeValueAsString(value);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Could not store idempotent response", e);
        }
    }

    private <T> T deserialize(String json, Class<T> type) {
        try {
            return objectMapper.readValue(json, type);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("Could not replay idempotent response", e);
        }
    }
}
