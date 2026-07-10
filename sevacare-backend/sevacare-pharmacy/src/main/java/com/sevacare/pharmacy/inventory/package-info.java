/**
 * Bounded context: Inventory
 *
 * <p>Owns stock as an append-only ledger of movements — receipts, issues, adjustments, transfers — never a mutable quantity. Balances are projections of the ledger. There is no {@code UPDATE stock SET qty = ?} anywhere in this system, by construction, because a quantity you can overwrite is a quantity whose history you have already lost.
 *
 * <p>Internally packaged {@code entity/repository/service/api}; those packages
 * are private to this context. Other contexts may import only
 * {@code com.sevacare.pharmacy.inventory.spi}, and otherwise learn what happened here
 * by subscribing to this context's domain events. {@code PharmacyBoundaryTest}
 * enforces both rules.
 */
package com.sevacare.pharmacy.inventory;
