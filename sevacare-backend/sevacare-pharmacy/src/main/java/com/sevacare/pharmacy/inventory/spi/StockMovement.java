package com.sevacare.pharmacy.inventory.spi;

import java.time.Instant;

/**
 * One thing that happened to stock. Positive {@code qtyDelta} is in, negative is
 * out; always in base units.
 *
 * @param refType      the kind of business document that caused this (SALE, GRN, …)
 * @param refId        its public id. A reference, never a foreign key: the causing
 *                     document may live in another context or in none at all
 * @param occurredAt   when it physically happened. Null means now. Backdating is a
 *                     normal operation, not an error — a truck that arrived on
 *                     Friday gets entered on Monday, and pretending otherwise is
 *                     how paper registers stay in business
 * @param deviceSeq    {@code "<device>:<counter>"} for offline uploads. Unique in the
 *                     ledger, so replaying an upload posts nothing twice
 * @param correctionOf the ledger id this entry reverses, if any
 */
public record StockMovement(
        String skuPublicId,
        String batchPublicId,
        String locationId,
        int qtyDelta,
        MovementReason reason,
        String refType,
        String refId,
        String actor,
        Instant occurredAt,
        String deviceSeq,
        Long correctionOf,
        String note) {

    public static StockMovement of(String skuPublicId, String batchPublicId, String locationId,
                                   int qtyDelta, MovementReason reason,
                                   String refType, String refId, String actor) {
        return new StockMovement(skuPublicId, batchPublicId, locationId, qtyDelta, reason,
                refType, refId, actor, null, null, null, null);
    }

    public boolean isOutbound() {
        return qtyDelta < 0;
    }
}
