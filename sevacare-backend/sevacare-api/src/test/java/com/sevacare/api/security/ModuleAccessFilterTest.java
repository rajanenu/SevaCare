package com.sevacare.api.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Set;

import org.junit.jupiter.api.Test;

import com.sevacare.tenant.capability.TenantManifest;

/**
 * The one line that decides whether a paying customer can reach a feature. Pure,
 * so it is tested without a servlet container, a database or a login.
 */
class ModuleAccessFilterTest {

    private static final TenantManifest STORE =
            new TenantManifest("T-1", "Store", false, "MEDICAL_STORE", Set.of());
    private static final TenantManifest HOSPITAL =
            new TenantManifest("T-2", "Hospital", true, null, Set.of());
    private static final TenantManifest BOTH =
            new TenantManifest("T-3", "Clinic", true, "CLINIC_DISPENSARY", Set.of());

    @Test
    void a_standalone_store_has_no_clinical_endpoints() {
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/doctors", STORE)).isTrue();
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/patients/P-0001", STORE)).isTrue();
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/prescriptions", STORE)).isTrue();
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/pharmacy/skus", STORE)).isFalse();
    }

    @Test
    void a_hospital_without_a_pharmacy_has_no_pharmacy_endpoints() {
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/pharmacy/skus", HOSPITAL)).isTrue();
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/doctors", HOSPITAL)).isFalse();
    }

    @Test
    void a_clinic_dispensary_reaches_both() {
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/doctors", BOTH)).isFalse();
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/pharmacy/sales", BOTH)).isFalse();
    }

    /**
     * Auth, discovery, admin and profile are not module scoped. Gating the admin
     * surface would lock a store owner out of their own settings, which is why
     * "clinical" means doctors, patients and prescriptions and nothing else.
     */
    @Test
    void shared_surfaces_are_never_gated() {
        for (TenantManifest tenant : new TenantManifest[]{STORE, HOSPITAL, BOTH}) {
            assertThat(ModuleAccessFilter.isBlocked("/api/v1/auth/login", tenant)).isFalse();
            assertThat(ModuleAccessFilter.isBlocked("/api/v1/public/tenants", tenant)).isFalse();
            assertThat(ModuleAccessFilter.isBlocked("/api/v1/admin/staff", tenant)).isFalse();
            assertThat(ModuleAccessFilter.isBlocked("/api/v1/capabilities", tenant)).isFalse();
            assertThat(ModuleAccessFilter.isBlocked("/actuator/health", tenant)).isFalse();
        }
    }

    /**
     * A tenant whose registry row vanished mid-session grants nothing. Failing
     * closed is the only safe direction when the question is "did they buy this?".
     */
    @Test
    void an_unknown_tenant_reaches_nothing() {
        TenantManifest unknown = new TenantManifest("T-9", null, false, null, Set.of());
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/doctors", unknown)).isTrue();
        assertThat(ModuleAccessFilter.isBlocked("/api/v1/pharmacy/skus", unknown)).isTrue();
    }
}
