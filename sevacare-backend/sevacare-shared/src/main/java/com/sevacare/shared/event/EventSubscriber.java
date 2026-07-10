package com.sevacare.shared.event;

/**
 * Reacts to a fact published by another context. Every Spring bean implementing
 * this interface is discovered by the dispatcher automatically.
 *
 * <p>Delivery is at-least-once. A subscriber that succeeds and then loses its
 * connection before the event is marked published will be handed the same event
 * again, so {@link #on} <strong>must</strong> be idempotent — keyed on
 * {@link DomainEvent#eventId()} or on a natural key of its own writes.
 *
 * <p>When {@link #on} throws, only this subscriber is retried; siblings that
 * already succeeded are not re-run. Throwing is the correct response to a
 * transient failure. For a permanent one, throwing still parks the event in the
 * dead-letter table after the attempt budget, which is what an operator wants to
 * see — swallowing the exception hides the bug instead.
 *
 * <p>{@code TenantContext} is set by the dispatcher before {@link #on} is
 * called, so a subscriber may use tenant-scoped repositories normally.
 */
public interface EventSubscriber {

    /**
     * Stable identity used to record what this subscriber has already consumed.
     * Renaming it makes every past event look unconsumed, so treat it as
     * permanent — it is effectively a database key.
     */
    String name();

    boolean handles(String eventType);

    void on(DomainEvent event);
}
