package com.sevacare.pharmacy.inventory.spi;

/**
 * How stock physically enters the building, for contexts that record the
 * business document around it (procurement's GRN, returns' claims). Inventory
 * owns batch identity — the caller describes the pack; this answers with the
 * batch id the ledger should move quantity into.
 */
public interface BatchIntake {

    /**
     * Finds the batch or creates it — idempotent on (sku, batch number), so the
     * same invoice re-posted after a network failure does not split one carton
     * across two batch records.
     *
     * @return the batch public id
     */
    String findOrCreateBatch(NewBatch batch);
}
