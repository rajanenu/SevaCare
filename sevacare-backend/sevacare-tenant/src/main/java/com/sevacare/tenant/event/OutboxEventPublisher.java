package com.sevacare.tenant.event;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.sevacare.shared.event.DomainEvent;
import com.sevacare.shared.event.EventPublisher;
import com.sevacare.shared.tenant.TenantContext;
import com.sevacare.tenant.support.TenantSchemas;

import java.sql.Timestamp;

/**
 * Writes the event into the current tenant's {@code outbox_event} table using the
 * caller's transaction and connection. Nothing is delivered here.
 *
 * <p>Unlike {@code WhatsAppService}'s enqueue, this one is allowed to throw: a
 * courtesy WhatsApp message must not fail the consult that produced it, but an
 * unrecorded domain fact means a consumer silently never runs. Losing the event
 * is worse than losing the transaction.
 */
@Component
public class OutboxEventPublisher implements EventPublisher {

    private final JdbcTemplate jdbcTemplate;
    private final ObjectMapper objectMapper;

    public OutboxEventPublisher(JdbcTemplate jdbcTemplate, ObjectMapper objectMapper) {
        this.jdbcTemplate = jdbcTemplate;
        this.objectMapper = objectMapper;
    }

    @Override
    public void publish(DomainEvent event) {
        String schema = TenantSchemas.require(TenantContext.tenantSchema());

        String payloadJson;
        try {
            payloadJson = objectMapper.writeValueAsString(event.payload());
        } catch (JsonProcessingException e) {
            throw new IllegalArgumentException(
                    "Event payload for " + event.eventType() + " is not serialisable", e);
        }

        jdbcTemplate.update(
                "INSERT INTO " + schema + ".outbox_event " +
                "(event_id, event_type, schema_version, tenant_public_id, location_id, aggregate_type, " +
                " aggregate_id, sequence_no, actor, occurred_at, payload) " +
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::jsonb)",
                event.eventId(),
                event.eventType(),
                event.schemaVersion(),
                event.tenantPublicId(),
                event.locationId(),
                event.aggregateType(),
                event.aggregateId(),
                event.sequence(),
                event.actor(),
                Timestamp.from(event.occurredAt()),
                payloadJson
        );
    }
}
