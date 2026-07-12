package com.sevacare.shared.event;

/**
 * A tenant has pharmacy switched on, and its schema is migrated and its registry
 * row committed. Published by the tenant context, which knows nothing of what a
 * pharmacy needs; consumed by the pharmacy context, which does.
 *
 * <p>Deliberately not a {@link DomainEvent} on the durable outbox: this is not a
 * business fact anyone replays, it is a provisioning step that must happen once the
 * transaction is real. It rides Spring's after-commit listener instead, so nothing
 * is seeded for a tenant whose onboarding ends up rolling back.
 */
public record PharmacyEnabledEvent(String tenantPublicId, String tenantSchema) {
}
