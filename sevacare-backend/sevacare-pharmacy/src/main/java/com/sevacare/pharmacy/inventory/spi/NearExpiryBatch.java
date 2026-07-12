package com.sevacare.pharmacy.inventory.spi;

import java.time.LocalDate;

/**
 * A batch with stock on hand that is close to, or past, its expiry — the queue
 * that turns dead stock into a supplier return while the claim window is open.
 */
public record NearExpiryBatch(
        String skuPublicId,
        String brandName,
        String batchPublicId,
        String batchNo,
        LocalDate expiryDate,
        long qtyOnHand,
        String batchStatus) {
}
