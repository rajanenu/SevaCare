package com.sevacare.pharmacy.inventory.service;

import java.time.LocalDate;

/**
 * @param batchNo    as printed on the pack. Matched case-insensitively, because
 *                   "ab1234" and "AB1234" are the same carton
 * @param expiryDate the last usable day, or null for items that do not expire
 *                   (surgical goods, devices). A fake expiry would poison the
 *                   near-expiry queue for every real one
 * @param mrpPaise   MRP per BASE unit, in paise: a strip of 10 at ₹50 is 500
 */
public record CreateBatchCommand(
        String skuPublicId,
        String batchNo,
        LocalDate expiryDate,
        long mrpPaise,
        Long purchasePricePaise,
        String supplierPublicId) {
}
