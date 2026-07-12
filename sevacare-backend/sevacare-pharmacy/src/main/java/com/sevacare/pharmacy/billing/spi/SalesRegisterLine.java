package com.sevacare.pharmacy.billing.spi;

import java.time.LocalDate;

/**
 * One line of the line-level sales register — what a drug inspector or the
 * owner's accountant asks for: exactly what left the shelf, on what invoice, on
 * what day. Unlike {@link TopMedicine} (a ranked summary over a window), this is
 * every row, unaggregated, so it can be exported and cross-checked line by line.
 *
 * @param itemName either the medicine's brand name or, for a manual line, what
 *                 the pharmacist typed (a courier bag, a delivery charge)
 */
public record SalesRegisterLine(
        LocalDate saleDate,
        String invoiceNo,
        String itemName,
        String batchNo,
        int qtyBaseUnits,
        long grossPaise,
        long gstPaise,
        long totalPaise) {
}
