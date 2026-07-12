package com.sevacare.pharmacy.returns.spi;

import java.util.List;

/** The record handed back after a customer return posts. */
public record PostedReturn(
        String returnPublicId,
        String salePublicId,
        long refundPaise,
        String refundMode,
        List<Line> lines) {

    public record Line(
            String skuPublicId,
            String brandName,
            String batchPublicId,
            int qtyBaseUnits,
            long amountPaise,
            String disposition) {
    }
}
