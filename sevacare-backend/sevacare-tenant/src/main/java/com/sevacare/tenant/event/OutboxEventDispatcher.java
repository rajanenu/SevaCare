package com.sevacare.tenant.event;

import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sevacare.shared.event.DomainEvent;
import com.sevacare.shared.event.EventSubscriber;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;
import com.sevacare.tenant.support.TenantSchemas;

/**
 * Polls every tenant's {@code outbox_event} table and hands due events to the
 * in-process subscribers. Polling now; {@code LISTEN/NOTIFY} when latency starts
 * to matter; a Pub/Sub publisher if a context ever leaves this deployable. None
 * of those changes touch a producer or a consumer — the outbox is the seam.
 *
 * <p>Rows are claimed with {@code FOR UPDATE SKIP LOCKED}, the same way
 * {@code WhatsAppService} drains its outbox, so several Cloud Run instances can
 * poll the same table without handling an event twice concurrently. The claim is
 * what makes the "already consumed?" check below safe to do outside a lock.
 */
@Component
public class OutboxEventDispatcher {

    private static final Logger log = LoggerFactory.getLogger(OutboxEventDispatcher.class);

    private static final int BATCH_SIZE = 100;
    private static final int MAX_ATTEMPTS = 8;

    /** An instance killed mid-dispatch strands rows in DISPATCHING; reclaim them. */
    private static final String RECLAIM_STALE_MINUTES = "15";

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;
    private final TenantRegistryRepository tenantRegistryRepository;
    private final List<EventSubscriber> subscribers;
    private final boolean enabled;

    /**
     * Schemas already known to carry an {@code outbox_event} table.
     *
     * <p>The dispatcher wakes every few seconds for every active tenant, and it used to
     * ask {@code information_schema.tables} each time whether that tenant's outbox
     * existed — a catalog view whose cost grows with the number of objects in the whole
     * database, so the check got slower with every tenant onboarded and ran forever
     * regardless. The answer is a one-way door: a migration creates the table and nothing
     * drops it. Remember it and the question is asked once per schema per boot.
     */
    private final Set<String> schemasWithOutbox = ConcurrentHashMap.newKeySet();

    public OutboxEventDispatcher(
            JdbcTemplate jdbcTemplate,
            ObjectMapper objectMapper,
            TenantRegistryRepository tenantRegistryRepository,
            List<EventSubscriber> subscribers,
            @Value("${sevacare.events.enabled:true}") boolean enabled
    ) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.subscribers = subscribers;
        this.enabled = enabled;
    }

    /**
     * The initial delay outruns the boot-time tenant migration sweep. A tenant
     * whose {@code outbox_event} table does not exist yet is skipped rather than
     * logged as an error, so a first boot after this migration is quiet.
     */
    @Scheduled(fixedDelayString = "${sevacare.events.dispatch-interval-ms:5000}",
               initialDelayString = "${sevacare.events.initial-delay-ms:60000}")
    public void dispatchAll() {
        if (!enabled) {
            return;
        }
        for (TenantRegistry tenant : tenantRegistryRepository.findByTenantStatus("active")) {
            try {
                dispatchForTenant(tenant);
            } catch (RuntimeException e) {
                // One tenant's broken outbox must not stop the others being drained.
                log.error("outbox_dispatch_failed tenantPublicId={} schemaName={}",
                        tenant.getTenantPublicId(), tenant.getTenantSchemaName(), e);
            }
        }
    }

    private void dispatchForTenant(TenantRegistry tenant) {
        String schema = TenantSchemas.require(tenant.getTenantSchemaName());
        String tenantPublicId = TenantSchemas.requireTenantId(tenant.getTenantPublicId());

        if (!hasOutboxTable(schema)) {
            return;
        }

        jdbcTemplate.update(
                "UPDATE " + schema + ".outbox_event SET status = 'PENDING' " +
                "WHERE status = 'DISPATCHING' " +
                "  AND next_attempt_at < CURRENT_TIMESTAMP - INTERVAL '" + RECLAIM_STALE_MINUTES + " minutes'");

        List<DomainEvent> due = claimDueEvents(schema);
        if (due.isEmpty()) {
            return;
        }

        String previousTenant = TenantContext.tenantPublicId();
        String previousSchema = TenantContext.tenantSchema();
        try {
            TenantContext.set(tenantPublicId, schema);
            for (DomainEvent event : due) {
                deliver(schema, event);
            }
        } finally {
            // The dispatcher runs on a scheduler thread that no filter will clean up.
            if (previousTenant == null) {
                TenantContext.clear();
            } else {
                TenantContext.set(previousTenant, previousSchema);
            }
        }
    }

    /**
     * Whether [schema] has an outbox to drain, asked at most once per schema per boot.
     *
     * <p>{@code to_regclass} is a syscache lookup that costs the same whatever else is in
     * the database; the {@code information_schema.tables} count it replaces scanned the
     * catalog and got slower as tenants were added. A schema that answers yes is
     * remembered, so the steady state asks nothing at all.
     */
    private boolean hasOutboxTable(String schema) {
        if (schemasWithOutbox.contains(schema)) {
            return true;
        }
        Boolean exists = jdbcTemplate.queryForObject(
                "SELECT to_regclass(?) IS NOT NULL", Boolean.class, schema + ".outbox_event");
        if (Boolean.TRUE.equals(exists)) {
            schemasWithOutbox.add(schema);
            return true;
        }
        // Not cached: a tenant migrated after boot must be picked up on a later tick.
        return false;
    }

    private List<DomainEvent> claimDueEvents(String schema) {
        return jdbcTemplate.query(
                "UPDATE " + schema + ".outbox_event SET status = 'DISPATCHING', attempts = attempts + 1, " +
                "       next_attempt_at = CURRENT_TIMESTAMP " +
                "WHERE event_id IN (SELECT event_id FROM " + schema + ".outbox_event " +
                "                   WHERE status = 'PENDING' AND next_attempt_at <= CURRENT_TIMESTAMP " +
                "                   ORDER BY occurred_at LIMIT " + BATCH_SIZE + " FOR UPDATE SKIP LOCKED) " +
                "RETURNING event_id, event_type, schema_version, tenant_public_id, location_id, " +
                "          aggregate_type, aggregate_id, sequence_no, actor, occurred_at, payload, attempts",
                (rs, i) -> new DomainEvent(
                        rs.getObject("event_id", UUID.class),
                        rs.getString("event_type"),
                        rs.getInt("schema_version"),
                        rs.getString("tenant_public_id"),
                        rs.getString("location_id"),
                        rs.getString("aggregate_type"),
                        rs.getString("aggregate_id"),
                        rs.getObject("sequence_no") == null ? null : rs.getLong("sequence_no"),
                        rs.getString("actor"),
                        rs.getTimestamp("occurred_at").toInstant(),
                        readPayload(rs.getString("payload"))));
    }

    private void deliver(String schema, DomainEvent event) {
        List<EventSubscriber> interested = subscribers.stream()
                .filter(s -> s.handles(event.eventType()))
                .toList();

        try {
            for (EventSubscriber subscriber : interested) {
                if (alreadyConsumed(schema, event.eventId(), subscriber.name())) {
                    continue;
                }
                subscriber.on(event);
                markConsumed(schema, event.eventId(), subscriber.name());
            }
        } catch (RuntimeException e) {
            failEvent(schema, event, e);
            return;
        }

        jdbcTemplate.update(
                "UPDATE " + schema + ".outbox_event SET status = 'PUBLISHED', published_at = CURRENT_TIMESTAMP, " +
                "last_error = NULL WHERE event_id = ?", event.eventId());

        // An event nobody subscribes to is published, not lost: it is a fact that
        // happened and was recorded. Consumers may be added later and replay it.
        if (interested.isEmpty()) {
            log.debug("outbox_event_no_subscriber eventType={} eventId={}", event.eventType(), event.eventId());
        }
    }

    /**
     * Retries with growing backoff, then dead-letters. The event stays in the
     * source table as DEAD so the aggregate's history has no hole; the copy in
     * the dead-letter table is what an operator triages.
     */
    private void failEvent(String schema, DomainEvent event, RuntimeException cause) {
        int attempts = currentAttempts(schema, event.eventId());
        if (attempts >= MAX_ATTEMPTS) {
            jdbcTemplate.update(
                    "INSERT INTO " + schema + ".outbox_event_dead_letter " +
                    "(event_id, event_type, tenant_public_id, aggregate_type, aggregate_id, payload, attempts, last_error, occurred_at) " +
                    "SELECT event_id, event_type, tenant_public_id, aggregate_type, aggregate_id, payload, attempts, ?, occurred_at " +
                    "FROM " + schema + ".outbox_event WHERE event_id = ? " +
                    "ON CONFLICT (event_id) DO NOTHING",
                    truncate(cause.getMessage()), event.eventId());
            jdbcTemplate.update(
                    "UPDATE " + schema + ".outbox_event SET status = 'DEAD', last_error = ? WHERE event_id = ?",
                    truncate(cause.getMessage()), event.eventId());
            log.error("outbox_event_dead_lettered eventType={} eventId={} attempts={}",
                    event.eventType(), event.eventId(), attempts, cause);
            return;
        }

        jdbcTemplate.update(
                "UPDATE " + schema + ".outbox_event SET status = 'PENDING', last_error = ?, " +
                "next_attempt_at = CURRENT_TIMESTAMP + (? * INTERVAL '10 seconds') WHERE event_id = ?",
                truncate(cause.getMessage()), (long) attempts * attempts, event.eventId());
        log.warn("outbox_event_retry eventType={} eventId={} attempts={} reason={}",
                event.eventType(), event.eventId(), attempts, cause.getMessage());
    }

    private int currentAttempts(String schema, UUID eventId) {
        Integer attempts = jdbcTemplate.queryForObject(
                "SELECT attempts FROM " + schema + ".outbox_event WHERE event_id = ?", Integer.class, eventId);
        return attempts == null ? MAX_ATTEMPTS : attempts;
    }

    private boolean alreadyConsumed(String schema, UUID eventId, String consumerName) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schema + ".outbox_event_consumption WHERE event_id = ? AND consumer_name = ?",
                Integer.class, eventId, consumerName);
        return count != null && count > 0;
    }

    private void markConsumed(String schema, UUID eventId, String consumerName) {
        jdbcTemplate.update(
                "INSERT INTO " + schema + ".outbox_event_consumption (event_id, consumer_name) VALUES (?, ?) " +
                "ON CONFLICT DO NOTHING", eventId, consumerName);
    }

    private Map<String, Object> readPayload(String json) {
        if (json == null || json.isBlank()) {
            return Map.of();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<Map<String, Object>>() {});
        } catch (Exception e) {
            throw new IllegalStateException("Unreadable outbox payload", e);
        }
    }

    private static String truncate(String message) {
        if (message == null) {
            return "unknown error";
        }
        return message.length() <= 500 ? message : message.substring(0, 500);
    }
}
