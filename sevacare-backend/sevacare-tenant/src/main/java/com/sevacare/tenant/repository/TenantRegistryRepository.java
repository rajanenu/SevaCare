package com.sevacare.tenant.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.tenant.entity.TenantRegistry;

public interface TenantRegistryRepository extends JpaRepository<TenantRegistry, String> {

    Optional<TenantRegistry> findByTenantPublicIdAndTenantStatus(String tenantPublicId, String tenantStatus);

    List<TenantRegistry> findByTenantStatus(String tenantStatus);
}
