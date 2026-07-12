package com.sevacare.pharmacy.inventory.spi;

import java.time.LocalDate;

/**
 * Identity and pricing for one batch, for a caller that named a specific batch
 * rather than letting FEFO choose — a pharmacist reading the strip in hand.
 *
 * @param expiryDate  the last usable day; null for items that do not expire
 * @param batchStatus ACTIVE / NEAR_EXPIRY / EXPIRED / QUARANTINED / RECALLED / DISPOSED
 */
public record BatchInfo(
        String batchPublicId,
        String skuPublicId,
        long mrpPaise,
        LocalDate expiryDate,
        String batchStatus) {

    /** Expired, quarantined or recalled stock is not sellable, whatever the date says. */
    public boolean isDispensable(LocalDate today) {
        if ("QUARANTINED".equals(batchStatus) || "RECALLED".equals(batchStatus) || "DISPOSED".equals(batchStatus)) {
            return false;
        }
        return expiryDate == null || !expiryDate.isBefore(today);
    }
}
