package com.sevacare.pharmacy.procurement.spi;

import java.time.Instant;

/** One goods receipt in the recent-deliveries list. */
public record GrnSummary(
        String grnPublicId,
        String supplierPublicId,
        String supplierName,
        String supplierInvoiceNo,
        int lineCount,
        long totalQtyBase,
        long totalCostPaise,
        Instant receivedAt) {
}
