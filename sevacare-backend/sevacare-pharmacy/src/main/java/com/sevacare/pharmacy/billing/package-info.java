/**
 * Bounded context: Pharmacy Billing and Money
 *
 * <p>Owns the pharmacy sale, its pricing, discounts, tax and tender. Money is integer minor units; a floating-point rupee is a bug waiting for an auditor.
 *
 * <p>Internally packaged {@code entity/repository/service/api}; those packages
 * are private to this context. Other contexts may import only
 * {@code com.sevacare.pharmacy.billing.spi}, and otherwise learn what happened here
 * by subscribing to this context's domain events. {@code PharmacyBoundaryTest}
 * enforces both rules.
 */
package com.sevacare.pharmacy.billing;
