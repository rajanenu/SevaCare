/**
 * Bounded context: Procurement
 *
 * <p>Owns suppliers, purchase orders, goods receipt notes, and the reorder suggestions raised when the ledger says stock has fallen. Receiving a GRN appends to the inventory ledger via an event; it never writes stock directly.
 *
 * <p>Internally packaged {@code entity/repository/service/api}; those packages
 * are private to this context. Other contexts may import only
 * {@code com.sevacare.pharmacy.procurement.spi}, and otherwise learn what happened here
 * by subscribing to this context's domain events. {@code PharmacyBoundaryTest}
 * enforces both rules.
 */
package com.sevacare.pharmacy.procurement;
