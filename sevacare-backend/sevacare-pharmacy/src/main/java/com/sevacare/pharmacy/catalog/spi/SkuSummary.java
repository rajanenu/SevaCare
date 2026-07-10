package com.sevacare.pharmacy.catalog.spi;

/**
 * What another context is allowed to know about a SKU: its identity, how it is
 * counted, how it is taxed, and whether it is restricted. No entity, no
 * repository, no table shape — so Catalog can be rebuilt or extracted without
 * every caller changing.
 *
 * @param scheduleClass H, H1, X, G or OTC; null for unscheduled items
 * @param gstRateBp     GST in basis points (500 = 5.00%), never a float
 */
public record SkuSummary(
        String skuPublicId,
        String brandName,
        String manufacturer,
        String strength,
        String dosageForm,
        BaseUnit baseUnit,
        String scheduleClass,
        String hsnCode,
        int gstRateBp,
        String rackLocation,
        boolean active) {

    /** Schedule H and H1 need a prescription; X needs one and a register entry. */
    public boolean isPrescriptionOnly() {
        return scheduleClass != null
                && ("H".equalsIgnoreCase(scheduleClass)
                 || "H1".equalsIgnoreCase(scheduleClass)
                 || "X".equalsIgnoreCase(scheduleClass));
    }
}
