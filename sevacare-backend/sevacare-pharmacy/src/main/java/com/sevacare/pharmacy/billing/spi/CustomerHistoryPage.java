package com.sevacare.pharmacy.billing.spi;

import java.util.List;

/**
 * One page of a customer's past invoices, keyed by mobile (preferred, since it is
 * the one identifier already used for khata and rebill) or by name when no mobile
 * was given. {@code totalCount} lets the counter show "New customer" the instant
 * it is zero, without the client having to guess from an empty first page.
 */
public record CustomerHistoryPage(
        int totalCount,
        int page,
        int size,
        List<SaleSummary> sales) {
}
