package com.sevacare.pharmacy.procurement.spi;

import java.util.List;

/**
 * The receipt handed back after a GRN posts: the document id and, per line, the
 * batch it landed in and the balance that batch now holds.
 */
public record PostedGrn(
        String grnPublicId,
        String supplierPublicId,
        int lineCount,
        long totalQtyBase,
        long totalCostPaise,
        List<Line> lines) {

    public record Line(
            String skuPublicId,
            String brandName,
            String batchPublicId,
            String batchNo,
            int qtyBaseUnits,
            int freeQtyBaseUnits,
            long balanceAfter) {
    }
}
