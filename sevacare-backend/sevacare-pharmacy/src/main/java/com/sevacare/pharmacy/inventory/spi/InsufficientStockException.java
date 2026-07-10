package com.sevacare.pharmacy.inventory.spi;

/**
 * Thrown only when {@code negative_stock} is ENFORCE. At OFF and SUGGEST the
 * balance is allowed to go negative, because a negative balance is the ledger
 * reporting that a receipt was never entered — information the store needs, not
 * a reason to refuse a customer holding cash.
 */
public class InsufficientStockException extends RuntimeException {

    private final String batchPublicId;
    private final String locationId;
    private final int requestedQty;

    public InsufficientStockException(String batchPublicId, String locationId, int requestedQty) {
        super("Insufficient stock for batch " + batchPublicId + " at " + locationId
                + " (requested " + Math.abs(requestedQty) + " base units)");
        this.batchPublicId = batchPublicId;
        this.locationId = locationId;
        this.requestedQty = requestedQty;
    }

    public String getBatchPublicId() {
        return batchPublicId;
    }

    public String getLocationId() {
        return locationId;
    }

    public int getRequestedQty() {
        return requestedQty;
    }
}
