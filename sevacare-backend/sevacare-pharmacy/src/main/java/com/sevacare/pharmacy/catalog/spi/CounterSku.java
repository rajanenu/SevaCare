package com.sevacare.pharmacy.catalog.spi;

/**
 * A SKU as the selling counter needs to see it: the product's identity plus the
 * two things a pharmacist decides on before adding it to a bill — how many are on
 * hand right now, and what the printed MRP is. Both are read from the ledger's
 * cache ({@code batch_balance}) and the batch FEFO would pick, so they are a
 * snapshot for display, never a source of truth for pricing (the sale re-reads
 * the batch inside its own transaction).
 *
 * @param qtyOnHand base units in stock across every batch of this SKU
 * @param mrpPaise  MRP of the earliest-expiry sellable batch, 0 if none in stock
 */
public record CounterSku(
        String skuPublicId,
        String brandName,
        String manufacturer,
        String strength,
        String dosageForm,
        BaseUnit baseUnit,
        String scheduleClass,
        int gstRateBp,
        String rackLocation,
        long qtyOnHand,
        long mrpPaise) {

    public boolean isPrescriptionOnly() {
        return scheduleClass != null
                && ("H".equalsIgnoreCase(scheduleClass)
                 || "H1".equalsIgnoreCase(scheduleClass)
                 || "X".equalsIgnoreCase(scheduleClass));
    }
}
