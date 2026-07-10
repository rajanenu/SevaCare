package com.sevacare.pharmacy.inventory.spi;

import java.util.List;

/**
 * The only way stock moves. Inventory is the sole context permitted to append to
 * the ledger; every other context sends it a movement and lets it record.
 *
 * <p>Inventory does not decide whether a movement <em>should</em> happen — that
 * is the caller's policy check. It records faithfully, including into a negative
 * balance, and the one exception is {@code negative_stock=ENFORCE}, which is a
 * rule about inventory's own table rather than about the caller's business.
 */
public interface StockLedger {

    /** @return the new ledger id */
    long append(StockMovement movement);

    /**
     * Appends several movements in one transaction, taking row locks in a
     * canonical order so that two multi-line sales touching the same batches
     * cannot deadlock each other. Prefer this over a loop of {@link #append}.
     */
    List<Long> appendAll(List<StockMovement> movements);

    /**
     * Reverses an entry with a compensating one. Nothing is ever edited or
     * deleted: the register must still show what was believed at the time, which
     * is both an audit requirement and, for controlled drugs, the law.
     */
    long reverse(long ledgerId, String actor, String note);

    /**
     * Earliest expiry first, skipping expired, quarantined and recalled batches —
     * expiry is re-checked against the date here rather than trusted from
     * {@code batch_status}, because the status is maintained by a scheduler and a
     * scheduler race has already bitten this codebase once.
     */
    BatchAllocation.Result allocateFefo(String skuPublicId, String locationId, int qtyBaseUnits);

    long balanceOf(String skuPublicId, String locationId);

    long balanceOfBatch(String batchPublicId, String locationId);
}
