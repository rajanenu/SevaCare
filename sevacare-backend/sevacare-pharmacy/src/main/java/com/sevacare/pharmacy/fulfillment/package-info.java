/**
 * Bounded context: Fulfillment
 *
 * <p>Owns the life of an order from prescription or counter request through picking to hand-over. Reservations are soft and expire; a sweeper releases them, is idempotent, and is lazily checked at read.
 *
 * <p>Internally packaged {@code entity/repository/service/api}; those packages
 * are private to this context. Other contexts may import only
 * {@code com.sevacare.pharmacy.fulfillment.spi}, and otherwise learn what happened here
 * by subscribing to this context's domain events. {@code PharmacyBoundaryTest}
 * enforces both rules.
 */
package com.sevacare.pharmacy.fulfillment;
