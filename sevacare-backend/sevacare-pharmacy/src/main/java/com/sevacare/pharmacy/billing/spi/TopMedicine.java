package com.sevacare.pharmacy.billing.spi;

/**
 * One row of the "what is selling" report: a SKU and its movement over a window.
 * The owner reads this to plan the next order, so it carries both units (how much
 * to reorder) and revenue (whether it is worth the shelf).
 *
 * @param qtySold      base units sold in the window
 * @param revenuePaise gross taken for those units, integer paise
 * @param billCount    distinct bills the SKU appeared on
 */
public record TopMedicine(
        String skuPublicId,
        String brandName,
        String dosageForm,
        long qtySold,
        long revenuePaise,
        long billCount) {
}
