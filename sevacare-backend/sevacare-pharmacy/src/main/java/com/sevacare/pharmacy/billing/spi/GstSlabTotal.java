package com.sevacare.pharmacy.billing.spi;

/**
 * One GST slab's totals over a window — the row the accountant transcribes at
 * filing time. Rate is basis points (1200 = 12%), amounts integer paise.
 */
public record GstSlabTotal(
        int gstRateBp,
        long taxablePaise,
        long gstPaise,
        long grossPaise,
        int lineCount) {
}
