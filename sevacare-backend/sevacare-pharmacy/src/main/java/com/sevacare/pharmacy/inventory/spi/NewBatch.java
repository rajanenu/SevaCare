package com.sevacare.pharmacy.inventory.spi;

import java.time.LocalDate;

/**
 * A batch as another context describes it off a supplier invoice: what is
 * printed on the pack, what was paid, who delivered it. Inventory decides
 * whether that is a new batch or the second carton of an existing one.
 *
 * @param purchasePricePaise effective cost per base unit (scheme-adjusted by
 *                           the caller), used by the owner's true-margin view
 */
public record NewBatch(
        String skuPublicId,
        String batchNo,
        LocalDate expiryDate,
        long mrpPaise,
        Long purchasePricePaise,
        String supplierPublicId) {
}
