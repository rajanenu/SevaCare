package com.sevacare.pharmacy.billing.spi;

import java.time.Instant;

/**
 * One row in the recent-sales / invoices list: enough to recognise a bill and
 * find its customer again, not the whole of it.
 *
 * @param status COMPLETED or VOID — a voided sale still appears (the audit
 *               trail, not the day's takings) so the counter can see it was
 *               reversed rather than have it silently vanish.
 */
public record SaleSummary(
        String salePublicId,
        String invoiceNo,
        Instant soldAt,
        String customerName,
        String customerMobile,
        PaymentMode paymentMode,
        int itemCount,
        long totalPaise,
        String status) {
}
