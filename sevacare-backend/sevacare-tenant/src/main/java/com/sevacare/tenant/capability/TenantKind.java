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
