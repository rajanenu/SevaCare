package com.sevacare.pharmacy.procurement.service;

import java.time.LocalDate;
import java.util.List;

/**
 * One delivery to record. Lines carry the invoice's own numbers — billed
 * quantity, free scheme quantity, printed MRP, invoice price per billed unit —
 * and the service derives everything else (batches, ledger rows, effective
 * unit cost).
 */
public record PostGrnCommand(
        String supplierPublicId,
        String supplierInvoiceNo,
        LocalDate invoiceDate,
        String note,
        String actor,
        List<LineRequest> lines) {

    public record LineRequest(
            String skuPublicId,
            String batchNo,
            LocalDate expiryDate,
            int qtyBaseUnits,
            int freeQtyBaseUnits,
            long mrpPaise,
            Long purchasePricePaise) {
    }
}
