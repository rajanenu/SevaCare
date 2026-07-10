/**
 * Bounded context: Compliance and Registers
 *
 * <p>Owns the statutory registers (Schedule H1, narcotics) and the audit trail that proves them. Every rule this context exposes is an OFF/SUGGEST/ENFORCE knob set per tenant — never block the sale. The single exception, with no OFF setting, is dispensing from an expired batch.
 *
 * <p>Internally packaged {@code entity/repository/service/api}; those packages
 * are private to this context. Other contexts may import only
 * {@code com.sevacare.pharmacy.compliance.spi}, and otherwise learn what happened here
 * by subscribing to this context's domain events. {@code PharmacyBoundaryTest}
 * enforces both rules.
 */
package com.sevacare.pharmacy.compliance;
