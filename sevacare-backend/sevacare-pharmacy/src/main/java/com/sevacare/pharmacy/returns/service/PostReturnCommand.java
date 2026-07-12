package com.sevacare.pharmacy.returns.service;

import java.util.List;

/**
 * A customer return against one bill. Lines name the (sku, batch) pair exactly
 * as the sale line did — one sale line per batch is the invariant that makes
 * this reference unambiguous — plus a per-line disposition: RESTOCK back to the
 * shelf, QUARANTINE if it must never be resold.
 */
public record PostReturnCommand(
        String salePublicId,
        String refundMode,
        String reason,
        String actor,
        List<LineRequest> lines) {

    public record LineRequest(
            String skuPublicId,
            String batchPublicId,
            int qtyBaseUnits,
            String disposition) {
    }
}
