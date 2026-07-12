package com.sevacare.pharmacy.returns.spi;

/**
 * One line of a bill, seen through the returns lens: what was sold, what has
 * already come back, and what one unit is worth in refund terms. The client
 * shows these; the server recomputes everything at post time — a stale screen
 * must not mint money.
 */
public record ReturnableLine(
        String skuPublicId,
        String brandName,
        String batchPublicId,
        int qtySold,
        int qtyAlreadyReturned,
        long netPaise,
        long perUnitPaise) {

    public int qtyReturnable() {
        return Math.max(0, qtySold - qtyAlreadyReturned);
    }
}
