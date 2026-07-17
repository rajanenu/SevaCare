package com.sevacare.pharmacy.refill.spi;

import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * One open refill cycle on the counter's worklist: this customer's purchase
 * rhythm for this SKU says they are running out around {@code dueDate}.
 * {@code notifiedAt} is set once the WhatsApp nudge has been queued.
 */
public record RefillDueItem(
        long id,
        String customerMobile,
        String customerName,
        String skuPublicId,
        String brandName,
        LocalDate lastSaleDate,
        int cadenceDays,
        LocalDate dueDate,
        String status,
        LocalDateTime notifiedAt) {
}
