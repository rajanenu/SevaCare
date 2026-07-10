/**
 * The published surface of the Fulfillment context: the only package inside
 * {@code com.sevacare.pharmacy.fulfillment} that another context may import.
 *
 * <p>Read-only lookups by public id belong here. Anything that writes belongs
 * behind a domain event instead — a context never writes another's state.
 */
package com.sevacare.pharmacy.fulfillment.spi;
