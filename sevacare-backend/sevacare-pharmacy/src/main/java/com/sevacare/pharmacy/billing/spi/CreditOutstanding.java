package com.sevacare.pharmacy.billing.spi;

import java.time.Instant;

/**
 * One customer's khata position: what they bought on credit, what came back
 * (refunds against those bills), what they have repaid, and the derived
 * balance. Outstanding is never stored anywhere — it is always this sum, so
 * it cannot drift from the sales and payments that justify it.
 */
public record CreditOutstanding(
        String customerMobile,
        String customerName,
        long creditPaise,
        long refundedPaise,
        long paidPaise,
        long outstandingPaise,
        Instant lastCreditAt) {
}
