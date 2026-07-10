package com.sevacare.pharmacy.inventory.spi;

/**
 * Facts inventory announces. Compliance registers, the reconciliation queue and
 * the owner's dashboards are all projections of these — nothing queries the hot
 * operational tables to build a report, which is what keeps a year-long margin
 * report at noon from threatening the twenty-second sale.
 */
public final class InventoryEvents {

    /** Every ledger append, without exception. The register is the event stream. */
    public static final String STOCK_MOVED = "pharmacy.stock.moved";

    /**
     * A balance crossed below zero under {@code negative_stock=SUGGEST}. Not an
     * error: it means a receipt was never entered or a count is stale, and it
     * becomes a task on the manager's reconciliation queue.
     */
    public static final String STOCK_WENT_NEGATIVE = "pharmacy.stock.negative_balance";

    private InventoryEvents() {
    }
}
