package com.sevacare.pharmacy.billing.spi;

/**
 * Facts billing announces. The owner's money view, GST returns and loyalty are
 * all projections of these — nothing rebuilds a sales report by scanning the
 * live tables, which is what keeps a month-end report from slowing the counter.
 */
public final class BillingEvents {

    /** A completed counter sale. Carries the invoice number and the money totals. */
    public static final String SALE_COMPLETED = "pharmacy.sale.completed";

    private BillingEvents() {
    }
}
