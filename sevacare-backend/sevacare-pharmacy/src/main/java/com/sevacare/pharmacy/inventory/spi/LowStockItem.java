package com.sevacare.pharmacy.inventory.spi;

/**
 * A SKU whose on-hand quantity has fallen to or below its reorder level — the
 * shopping list. Only SKUs the tenant chose to track (reorder level set) appear.
 */
public record LowStockItem(
        String skuPublicId,
        String brandName,
        long qtyOnHand,
        int reorderLevel,
        Integer reorderQty) {
}
