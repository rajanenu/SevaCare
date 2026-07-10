package com.sevacare.shared.event;

/**
 * Records a fact for later delivery.
 *
 * <p>Call this <em>inside</em> the transaction that produced the fact. The event
 * row is written to the same tenant schema in the same transaction as the
 * aggregate, so the fact and its announcement commit or roll back together —
 * there is no window in which a sale exists but its event does not, and no
 * distributed transaction is needed to get that.
 *
 * <p>Publishing therefore does not deliver anything. Delivery is a separate,
 * retrying concern owned by the dispatcher.
 */
public interface EventPublisher {

    void publish(DomainEvent event);
}
