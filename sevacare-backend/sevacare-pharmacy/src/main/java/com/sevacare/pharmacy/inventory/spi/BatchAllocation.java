package com.sevacare.pharmacy.inventory.spi;

import java.time.LocalDate;
import java.util.List;

/**
 * Which batch supplies how many base units, and at what MRP. A sale line becomes
 * one of these per batch it draws from — a strip of 10 taken from two batches is
 * two allocations and two ledger rows, because a recall must be able to find
 * exactly which patient got which batch.
 */
public record BatchAllocation(
        String batchPublicId,
        int qtyBaseUnits,
        LocalDate expiryDate,
        long mrpPaise) {

    /**
     * The result of asking inventory for stock.
     *
     * <p>{@code shortfallBaseUnits} is the part that could not be allocated, and
     * it is returned rather than thrown because whether a shortfall is fatal is
     * the caller's policy, not inventory's. A store selling on credit against
     * tomorrow's delivery is a real store; inventory records, it does not judge.
     */
    public record Result(List<BatchAllocation> allocations, int shortfallBaseUnits) {

        public boolean isComplete() {
            return shortfallBaseUnits == 0;
        }

        public int allocatedBaseUnits() {
            return allocations.stream().mapToInt(BatchAllocation::qtyBaseUnits).sum();
        }
    }
}
