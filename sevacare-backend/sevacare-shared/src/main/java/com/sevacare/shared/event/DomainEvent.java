package com.sevacare.shared.event;

import java.time.Instant;
import java.util.Map;
import java.util.UUID;

import com.sevacare.shared.tenant.TenantContext;

/**
 * A fact that already happened, in the past tense, published by the context that
 * owns it. Consumers react; they never reach back into the producer.
 *
 * <p>Envelope shape is fixed by the pharmacy blueprint §9.2 so that the day a
 * context moves out of this monolith, the dispatcher grows a Pub/Sub publisher
 * and neither producers nor consumers change.
 *
 * @param eventId       stable identity; consumers deduplicate on it
 * @param eventType     dotted name, e.g. {@code pharmacy.sale.completed}
 * @param schemaVersion bumped when {@code payload} changes shape incompatibly
 * @param locationId    null until a tenant runs more than one physical location
 * @param sequence      producer-assigned ordering within one aggregate; null when unordered
 * @param actor         user id that caused the fact, null for system-generated events
 * @param occurredAt    when the fact happened (not when it was written)
 */
public record DomainEvent(
        UUID eventId,
        String eventType,
        int schemaVersion,
        String tenantPublicId,
        String locationId,
        String aggregateType,
        String aggregateId,
        Long sequence,
        String actor,
        Instant occurredAt,
        Map<String, Object> payload
) {

    /**
     * Builds an event for the tenant of the current request. The caller is
     * inside a business transaction, so the tenant is always in scope; a null
     * here means something published from a thread that forgot to set it, which
     * would silently write the row into the wrong schema.
     */
    public static DomainEvent of(String eventType, String aggregateType, String aggregateId,
                                 Map<String, Object> payload) {
        String tenantPublicId = TenantContext.tenantPublicId();
        if (tenantPublicId == null || tenantPublicId.isBlank()) {
            throw new IllegalStateException(
                    "No tenant in context while publishing " + eventType + "; set TenantContext first");
        }
        return new DomainEvent(
                UUID.randomUUID(), eventType, 1, tenantPublicId, null,
                aggregateType, aggregateId, null, null, Instant.now(),
                payload == null ? Map.of() : payload);
    }

    public DomainEvent withSequence(long sequence) {
        return new DomainEvent(eventId, eventType, schemaVersion, tenantPublicId, locationId,
                aggregateType, aggregateId, sequence, actor, occurredAt, payload);
    }

    public DomainEvent withActor(String actor) {
        return new DomainEvent(eventId, eventType, schemaVersion, tenantPublicId, locationId,
                aggregateType, aggregateId, sequence, actor, occurredAt, payload);
    }
}
