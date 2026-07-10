/**
 * The published surface of the Pharmacy Billing and Money context: the only package inside
 * {@code com.sevacare.pharmacy.billing} that another context may import.
 *
 * <p>Read-only lookups by public id belong here. Anything that writes belongs
 * behind a domain event instead — a context never writes another's state.
 */
package com.sevacare.pharmacy.billing.spi;
