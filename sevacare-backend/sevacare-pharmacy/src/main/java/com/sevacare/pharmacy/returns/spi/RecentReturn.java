package com.sevacare.pharmacy.returns.spi;

import java.time.Instant;

/**
 * One row of the refund history — the answer to "where did my refunded money
 * go", which a write-only return flow could never show.
 */
public record RecentReturn(
        String returnPublicId,
        String salePublicId,
        String invoiceNo,
        long refundPaise,
        String refundMode,
        String reason,
        Instant returnedAt,
        int lineCount) {
}
