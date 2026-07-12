package com.sevacare.pharmacy.procurement.spi;

/**
 * Facts procurement announces. Payables, supplier scorecards and price-history
 * analytics are projections of these.
 */
public final class ProcurementEvents {

    /** A goods receipt posted: batches exist, stock is in, money is owed. */
    public static final String GRN_POSTED = "pharmacy.grn.posted";

    private ProcurementEvents() {
    }
}
