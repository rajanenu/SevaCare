package com.sevacare.admin.repository;

import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;

import com.sevacare.admin.entity.AdminUser;

public interface AdminUserRepository extends JpaRepository<AdminUser, String> {

    Optional<AdminUser> findFirstByTenantPublicIdAndActiveTrueOrderByAdminPublicIdAsc(String tenantPublicId);

    Optional<AdminUser> findByTenantPublicIdAndMobileNumberAndActiveTrue(String tenantPublicId, String mobileNumber);

    List<AdminUser> findByTenantPublicIdOrderByAdminPublicIdAsc(String tenantPublicId);

    List<AdminUser> findByTenantPublicIdAndActiveTrueOrderByAdminPublicIdAsc(String tenantPublicId);

    Optional<AdminUser> findByTenantPublicIdAndEmailIgnoreCase(String tenantPublicId, String email);
}
