package com.sevacare.pharmacy.billing.service;

import java.util.List;

import com.sevacare.pharmacy.billing.spi.PaymentMode;

/**
 * A counter sale as the pharmacist entered it. Prices are not here — the sale is
 * billed at the batch's printed MRP, so the client says <em>what</em> and <em>how
 * many</em>, and billing decides the money. The one price the client may send is
 * {@code mrpOverridePaise}, and only where policy allows a price edit.
 *
 * @param actor who rang it up; filled from the authenticated user, not the client
 */
public record CreateSaleCommand(
        String customerName,
        String customerMobile,
        String prescriberName,
        PaymentMode paymentMode,
        String actor,
        String note,
        List<LineRequest> lines) {

    /**
     * @param skuPublicId      a catalog SKU, or null for a manual (non-catalog) line —
     *                         in which case {@code manualLabel} and {@code
     *                         manualAmountPaise} must both be set instead
     * @param batchPublicId    a specific batch, or null to let FEFO choose; ignored for
     *                         a manual line
     * @param discountPaise    a line discount off the MRP total, or null for none
     * @param mrpOverridePaise a hand-keyed price per base unit, or null to bill at
     *                         the batch MRP; honoured only under a permissive
     *                         price-edit policy
     * @param manualLabel      what the pharmacist typed for a non-catalog line
     *                         ("Delivery charge"), or null for a catalog line
     * @param manualAmountPaise the flat amount charged for a manual line, or null
     *                         for a catalog line
     */
    public record LineRequest(
            String skuPublicId,
            int qtyBaseUnits,
            String batchPublicId,
            Long discountPaise,
            Long mrpOverridePaise,
            String manualLabel,
            Long manualAmountPaise) {

        public boolean isManual() {
            return skuPublicId == null || skuPublicId.isBlank();
        }
    }
}
