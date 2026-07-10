package com.sevacare.pharmacy.inventory.spi;

/**
 * Why stock moved. Mirrors the {@code ck_ledger_reason} check in the V3 tenant
 * migration; adding a constant here without adding it there fails at insert.
 *
 * <p>Note that a reason does not imply a direction. A correction of a GRN is a
 * negative {@code GRN} row, not a positive {@code ADJUST} — the reason records
 * why the stock moved in the world, and the bookkeeping that fixed a typo does
 * not change that answer. The reversal chain, not the reason, says "this undoes
 * that".
 */
public enum MovementReason {

    /** Stock that existed before SevaCare did. Cites the import, not a document. */
    OPENING,

    GRN,
    SALE,

    /** A customer brought it back and it is sellable again. */
    RETURN_IN,

    /** It went back to the supplier — the expiry-claim loop where the money is. */
    RETURN_OUT,

    TRANSFER_OUT,
    TRANSFER_IN,

    /** A human decided the number was wrong. Reason capture is mandatory upstream. */
    ADJUST,

    /** A count found a difference. Distinct from ADJUST because it is scheduled, not reactive. */
    CYCLE_COUNT,

    WARD_ISSUE,
    DAMAGE,

    /** Pulled from sale into quarantine ahead of a supplier return or disposal. */
    EXPIRY_QUARANTINE,

    DISPOSAL
}
