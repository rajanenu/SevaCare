package com.sevacare.pharmacy.capability.spi;

import java.util.Set;

import static com.sevacare.pharmacy.capability.spi.PolicyMode.ENFORCE;
import static com.sevacare.pharmacy.capability.spi.PolicyMode.OFF;
import static com.sevacare.pharmacy.capability.spi.PolicyMode.SUGGEST;

/**
 * The knobs. {@link #storageKey()} is the string used in
 * {@code platform.capability_profile.policy_defaults} and in the tenant's
 * {@code pharmacy_config} table, so renaming a constant here without a migration
 * silently reverts a tenant to the platform default.
 *
 * <p>{@link #platformDefault()} is the bottom of the resolution chain and the
 * answer for a tenant whose profile says nothing about a knob — which is the
 * normal case for knobs added after a profile was written.
 */
public enum PolicyKey {

    /**
     * May a sale line leave the counter without a batch chosen? At SUGGEST the
     * allocator picks FEFO and shows it; at ENFORCE the pharmacist confirms.
     * Making the pharmacist pick a batch per line is the single biggest speed
     * killer at an Indian counter, which is why ENFORCE is not the default.
     */
    BATCH_ON_SALE_LINE("batch_on_sale_line", SUGGEST),

    /** Schedule H/H1 without a prescription: amber strip and a logged skip, or a hard stop. */
    RX_REQUIRED_FOR_SCHEDULE_H("rx_required_for_schedule_h", SUGGEST),

    /**
     * The one knob with no OFF. Dispensing an expired medicine is not a
     * configuration preference, and a tenant who wants it off is telling us
     * something we should not accommodate.
     */
    EXPIRED_BATCH_DISPENSE("expired_batch_dispense", ENFORCE, Set.of(ENFORCE)),

    /** Selling above the DPCO ceiling price. */
    ABOVE_CEILING_PRICE_SALE("above_ceiling_price_sale", SUGGEST),

    /**
     * A negative balance is the ledger reporting that a GRN was never entered or
     * a count is stale — information, not corruption. At SUGGEST it is allowed
     * and raises a reconciliation task. Only a corporate deployment with clean
     * data should ENFORCE it; a store that ENFORCEs it on day one cannot sell
     * the stock sitting on its own shelf.
     */
    NEGATIVE_STOCK("negative_stock", SUGGEST),

    /** Allocate the earliest expiry first, or let the user choose the batch. */
    FEFO_ALLOCATION("fefo_allocation", SUGGEST),

    /** Editing the price at billing, below the margin floor. */
    PRICE_EDIT_AT_BILLING("price_edit_at_billing", SUGGEST);

    private final String storageKey;
    private final PolicyMode platformDefault;
    private final Set<PolicyMode> allowedModes;

    PolicyKey(String storageKey, PolicyMode platformDefault) {
        this(storageKey, platformDefault, Set.of(OFF, SUGGEST, ENFORCE));
    }

    PolicyKey(String storageKey, PolicyMode platformDefault, Set<PolicyMode> allowedModes) {
        this.storageKey = storageKey;
        this.platformDefault = platformDefault;
        this.allowedModes = allowedModes;
    }

    public String storageKey() {
        return storageKey;
    }

    public PolicyMode platformDefault() {
        return platformDefault;
    }

    /**
     * A stored value outside this set is treated as absent rather than obeyed.
     * A row that says {@code expired_batch_dispense=OFF} — from a bad import, a
     * hand-edited database, a future bug — must not be the reason a patient is
     * handed an expired drug.
     */
    public boolean allows(PolicyMode mode) {
        return allowedModes.contains(mode);
    }

    public static PolicyKey fromStorageKey(String storageKey) {
        for (PolicyKey key : values()) {
            if (key.storageKey.equals(storageKey)) {
                return key;
            }
        }
        throw new IllegalArgumentException("Unknown policy key: " + storageKey);
    }
}
