package com.sevacare.tenant.capability;

/**
 * The single onboarding question — "what are you?" — in the words a shop owner
 * would use, not ours.
 *
 * <p>This is a UI-facing input, never a stored column. It maps onto the two
 * switches on {@code tenant_registry} and is then forgotten, because an answer
 * that can be recomputed from the switches is a second source of truth waiting
 * to disagree with the first.
 */
public enum TenantKind {

    /** A shop. No doctors, no appointments, no patient records. Sells medicine. */
    MEDICAL_STORE(false, "MEDICAL_STORE"),

    /** Consultations only. The pharmacy can be switched on later without a migration. */
    HOSPITAL(true, null),

    /** A clinic or hospital that dispenses what its doctors prescribe. */
    HOSPITAL_WITH_PHARMACY(true, "CLINIC_DISPENSARY");

    private final boolean clinicalEnabled;
    private final String pharmacyProfileKey;

    TenantKind(boolean clinicalEnabled, String pharmacyProfileKey) {
        this.clinicalEnabled = clinicalEnabled;
        this.pharmacyProfileKey = pharmacyProfileKey;
    }

    public boolean clinicalEnabled() {
        return clinicalEnabled;
    }

    /** Null when this kind has no pharmacy. Onboarding may override with a bigger profile. */
    public String pharmacyProfileKey() {
        return pharmacyProfileKey;
    }

    /**
     * What the onboarding form actually collects: two checkboxes. "Hospital" and
     * "Pharmacy" are things a business <em>has</em>, not types it <em>is</em>, and
     * plenty of Indian clinics have both — so asking one either/or question would
     * force half our customers to lie.
     */
    public static TenantKind of(boolean clinical, boolean pharmacy) {
        if (clinical && pharmacy) {
            return HOSPITAL_WITH_PHARMACY;
        }
        if (clinical) {
            return HOSPITAL;
        }
        if (pharmacy) {
            return MEDICAL_STORE;
        }
        throw new IllegalArgumentException(
                "Select at least one: a hospital, a pharmacy, or both. A tenant with neither has nothing to log in to.");
    }

    /** The words a platform admin reads back on the tenant list. */
    public String displayName() {
        return switch (this) {
            case MEDICAL_STORE -> "Pharmacy only";
            case HOSPITAL -> "Hospital only";
            case HOSPITAL_WITH_PHARMACY -> "Hospital + Pharmacy";
        };
    }

    public static TenantKind parse(String raw) {
        if (raw == null || raw.isBlank()) {
            return HOSPITAL;
        }
        try {
            return valueOf(raw.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            return HOSPITAL;
        }
    }
}
