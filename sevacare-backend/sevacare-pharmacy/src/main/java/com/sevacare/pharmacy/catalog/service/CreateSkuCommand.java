package com.sevacare.pharmacy.catalog.service;

import java.util.List;

import com.sevacare.pharmacy.catalog.spi.BaseUnit;

/**
 * Everything needed to stock something new. Only {@code brandName} is required —
 * a pharmacist adding an item mid-sale should not be stopped by an HSN code they
 * will look up this evening.
 *
 * @param packs pack levels above the base unit, e.g. STRIP=10, BOX=100. The base
 *              level is added automatically; passing it here is not an error, it
 *              is simply redundant.
 */
public record CreateSkuCommand(
        String brandName,
        String manufacturer,
        String dosageForm,
        String strength,
        BaseUnit baseUnit,
        String scheduleClass,
        String hsnCode,
        Integer gstRateBp,
        String rackLocation,
        Integer reorderLevel,
        Integer reorderQty,
        String drugPublicId,
        List<PackLevel> packs,
        List<String> aliases) {

    /** @param unitsInPack how many base units this level contains, e.g. STRIP → 10 */
    public record PackLevel(String packName, int unitsInPack, boolean sellable) {
    }
}
