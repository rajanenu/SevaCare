package com.sevacare.pharmacy.billing.spi;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/**
 * A completed sale as the customer's bill and the shop's record — the numbers
 * that were charged, the batches that left, and any warnings the counter should
 * have seen (a Schedule H item sold without a prescriber, a sale beyond recorded
 * stock). All money is integer paise.
 *
 * <p>{@code warnings} is deliberately part of the receipt rather than an
 * exception: at the default policy the sale <em>succeeded</em>, and the pharmacist
 * needs both the bill and the note about what to reconcile, not one or the other.
 */
public record SaleReceipt(
        String salePublicId,
        String invoiceNo,
        LocalDate saleDate,
        Instant soldAt,
        String customerName,
        String customerMobile,
        String prescriberName,
        PaymentMode paymentMode,
        long grossPaise,
        long discountPaise,
        long taxablePaise,
        long gstPaise,
        long totalPaise,
        List<Line> lines,
        List<String> warnings,
        String waLink) {

    public record Line(
            String skuPublicId,
            String brandName,
            String batchPublicId,
            LocalDate expiryDate,
            String scheduleClass,
            int qtyBaseUnits,
            long mrpPaise,
            long grossPaise,
            long discountPaise,
            int gstRateBp,
            long taxablePaise,
            long gstPaise) {
    }
}
