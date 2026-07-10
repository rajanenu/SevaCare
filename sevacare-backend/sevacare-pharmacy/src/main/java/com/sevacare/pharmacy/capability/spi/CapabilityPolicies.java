package com.sevacare.pharmacy.capability.spi;

/**
 * Resolves a policy for the tenant in {@code TenantContext}. Every other context
 * reads its rules through this and never touches the config table.
 */
public interface CapabilityPolicies {

    /**
     * The mode in force, resolved platform default → profile → tenant override.
     * Never returns null: a knob nobody has an opinion about resolves to
     * {@link PolicyKey#platformDefault()}.
     */
    PolicyMode modeOf(PolicyKey key);

    /**
     * Has this tenant chosen a pharmacy capability profile? A hospital that has
     * not is a hospital without a pharmacy, and every pharmacy endpoint should
     * behave as though the module were not installed.
     */
    boolean pharmacyEnabled();

    /** The tenant's profile key, or null when the tenant has no pharmacy. */
    String profileKey();
}
