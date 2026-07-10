/**
 * Bounded context: Catalog
 *
 * <p>Owns what a product *is*: drug/SKU identity, pack sizes, schedule classification (H, H1, X), tax class, and the tenant-local mapping from a doctor's free-text prescription line to a stocked SKU. Free text stays legal forever; resolution is a learning engine, never a gate.
 *
 * <p>Internally packaged {@code entity/repository/service/api}; those packages
 * are private to this context. Other contexts may import only
 * {@code com.sevacare.pharmacy.catalog.spi}, and otherwise learn what happened here
 * by subscribing to this context's domain events. {@code PharmacyBoundaryTest}
 * enforces both rules.
 */
package com.sevacare.pharmacy.catalog;
