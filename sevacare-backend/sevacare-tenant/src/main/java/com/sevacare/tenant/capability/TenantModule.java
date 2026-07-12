package com.sevacare.tenant.capability;

/**
 * Which module a caller is shopping for when it asks the public directory for tenants.
 *
 * <p>This is the filter, not the tenant's identity: a tenant is a <em>set</em> of modules
 * (see {@link TenantModuleService}), so a hospital that also runs a dispensary answers to
 * both {@link #CLINICAL} and {@link #PHARMACY}. Asking for neither means "everything".
 */
public enum TenantModule {
    /** Doctors, patients, prescriptions — what "Search Hospitals" wants. */
    CLINICAL,
    /** A dispensing counter — what "Search Pharmacies" wants. */
    PHARMACY;

    /**
     * Parses the {@code ?module=} query param. Anything unrecognised — including null and
     * blank — means "no filter", so an old client that sends nothing still sees every
     * tenant and a typo degrades to a wider list rather than an error page.
     */
    public static TenantModule parseOrNull(String raw) {
        if (raw == null || raw.isBlank()) {
            return null;
        }
        return switch (raw.trim().toUpperCase(java.util.Locale.ROOT)) {
            case "CLINICAL", "HOSPITAL", "HOSPITALS" -> CLINICAL;
            case "PHARMACY", "PHARMACIES", "STORE" -> PHARMACY;
            default -> null;
        };
    }
}
