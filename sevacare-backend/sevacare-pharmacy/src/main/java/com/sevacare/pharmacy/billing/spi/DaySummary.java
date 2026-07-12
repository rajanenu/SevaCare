package com.sevacare.pharmacy.billing.spi;

import java.time.LocalDate;
import java.util.List;

/**
 * The day-close (Z-report): one calendar day's takings, split by tender so the
 * cash drawer can be counted against CASH alone and CREDIT is never mistaken for
 * money in hand. All amounts are integer paise.
 */
public record DaySummary(
        LocalDate saleDate,
        int saleCount,
        long grossPaise,
        long discountPaise,
        long taxablePaise,
        long gstPaise,
        long totalPaise,
        List<PaymentTotal> byPaymentMode) {

    public record PaymentTotal(PaymentMode paymentMode, int saleCount, long totalPaise) {
    }
}
