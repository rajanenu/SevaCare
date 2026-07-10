package com.sevacare.tenant.capability;

import java.util.Set;

/**
 * What this tenant has bought. The API gates on it and the client builds its
 * navigation from it, so a medical store does not see a greyed-out "Doctors"
 * tab — it sees no such tab at all (blueprint §10.1, Layer 2).
 *
 * @param pharmacyFeatures the fine-grained flags from the tenant's capability
 *                         profile: {@code wards}, {@code rx_queue}, {@code transfers}…
 *                         Empty when the tenant has no pharmacy.
 */
public record TenantManifest(
        String tenantPublicId,
        String tenantName,
        boolean clinicalEnabled,
        String pharmacyProfileKey,
        Set<String> pharmacyFeatures) {

    public boolean pharmacyEnabled() {
        return pharmacyProfileKey != null && !pharmacyProfileKey.isBlank();
    }

    public boolean hasPharmacyFeature(String feature) {
        return pharmacyFeatures.contains(feature);
    }

    /** The module names a client should render navigation for. */
    public Set<String> enabledModules() {
        if (clinicalEnabled && pharmacyEnabled()) {
            return Set.of("clinical", "pharmacy");
        }
        return clinicalEnabled ? Set.of("clinical") : Set.of("pharmacy");
    }
}
