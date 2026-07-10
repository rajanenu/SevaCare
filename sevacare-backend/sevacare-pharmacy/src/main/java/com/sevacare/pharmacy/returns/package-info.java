/**
 * Bounded context: Returns and Recalls
 *
 * <p>Owns customer returns, supplier returns, expiry write-offs, and batch recalls. A recall is a query over the ledger — which batch went to whom — which is only answerable because the ledger was never overwritten.
 *
 * <p>Internally packaged {@code entity/repository/service/api}; those packages
 * are private to this context. Other contexts may import only
 * {@code com.sevacare.pharmacy.returns.spi}, and otherwise learn what happened here
 * by subscribing to this context's domain events. {@code PharmacyBoundaryTest}
 * enforces both rules.
 */
package com.sevacare.pharmacy.returns;
