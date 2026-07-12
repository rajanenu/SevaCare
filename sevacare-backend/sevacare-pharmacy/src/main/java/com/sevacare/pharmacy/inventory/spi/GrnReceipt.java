package com.sevacare.pharmacy.inventory.spi;

/**
 * The outcome of receiving stock: which batch it landed in and the balance after.
 * Re-receiving the same batch number returns the same {@code batchPublicId}, so a
 * retried GRN reads as "now there are more", never as a second carton.
 */
public record GrnReceipt(
        String batchPublicId,
        String skuPublicId,
        int qtyBaseUnits,
        long balanceAfter,
        long ledgerId) {
}
