package com.sevacare.tenant.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.tenant.entity.TenantRegistry;

public interface TenantRegistryRepository extends JpaRepository<TenantRegistry, String> {

    Optional<TenantRegistry> findByTenantPublicIdAndTenantStatus(String tenantPublicId, String tenantStatus);

    List<TenantRegistry> findByTenantStatus(String tenantStatus);

    /**
     * Hospitals: tenants whose clinical module is on. A store that also runs a clinic
     * belongs here too — the question is "can I book a doctor", not "is it only a hospital".
     */
    List<TenantRegistry> findByTenantStatusAndClinicalEnabledTrue(String tenantStatus);

    /**
     * Medical stores: a NULL {@code pharmacy_profile_key} is precisely "no pharmacy"
     * (see TenantModuleService), so a non-NULL key is the whole test.
     */
    List<TenantRegistry> findByTenantStatusAndPharmacyProfileKeyIsNotNull(String tenantStatus);
}
