package com.sevacare.tenant.service;

import java.util.Comparator;
import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.PlatformAdminDtos;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;

@Service
public class PlatformAdminService {

    public static final String PLATFORM_TENANT_PUBLIC_ID = "platform";

    private final TenantRegistryRepository tenantRegistryRepository;
    private final JdbcTemplate jdbcTemplate;

    public PlatformAdminService(TenantRegistryRepository tenantRegistryRepository, JdbcTemplate jdbcTemplate) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public String findDefaultPlatformAdminPublicId() {
        String subjectPublicId = jdbcTemplate.query(
                """
                SELECT platform_admin_public_id
                FROM public.platform_admin_user
                WHERE active = true
                ORDER BY created_at ASC, platform_admin_public_id ASC
                LIMIT 1
                """,
                rs -> rs.next() ? rs.getString("platform_admin_public_id") : null
        );

        if (subjectPublicId == null || subjectPublicId.isBlank()) {
            throw new IllegalArgumentException("No platform admin exists");
        }

        return subjectPublicId;
    }

    @Transactional(readOnly = true)
    public PlatformAdminDtos.PlatformAdminOverview overview() {
        long activeTenants = tenantRegistryRepository.findByTenantStatus("active").size();
        long onboardingRequests = queryCount("SELECT COUNT(*) FROM public.tenant_onboarding_request WHERE request_status = 'submitted'");
        long approvedOnboardings = queryCount("SELECT COUNT(*) FROM public.tenant_onboarding_request WHERE request_status = 'approved'");
        long platformAdmins = queryCount("SELECT COUNT(*) FROM public.platform_admin_user WHERE active = true");
        return new PlatformAdminDtos.PlatformAdminOverview(activeTenants, onboardingRequests, approvedOnboardings, platformAdmins);
    }

    @Transactional(readOnly = true)
    public PlatformAdminDtos.PlatformTenantCollection listTenants() {
        List<PlatformAdminDtos.PlatformTenantView> tenants = tenantRegistryRepository.findAll()
                .stream()
                .sorted(Comparator.comparing(TenantRegistry::getTenantPublicId))
                .map(tenant -> new PlatformAdminDtos.PlatformTenantView(
                        tenant.getTenantPublicId(),
                        tenant.getTenantName(),
                        tenant.getTenantThemeKey(),
                        tenant.getTenantSchemaName(),
                        tenant.getTenantStatus()
                ))
                .toList();
        return new PlatformAdminDtos.PlatformTenantCollection(tenants);
    }

    @Transactional(readOnly = true)
    public PlatformAdminDtos.PlatformOnboardingCollection listOnboardingRequests() {
        List<PlatformAdminDtos.PlatformOnboardingRequestView> requests = jdbcTemplate.query(
                """
                SELECT request_public_id, hospital_name, city, facility_type, request_status,
                       contact_name, contact_mobile, contact_email, requested_at
                FROM public.tenant_onboarding_request
                ORDER BY requested_at DESC, request_public_id DESC
                """,
                (rs, rowNum) -> new PlatformAdminDtos.PlatformOnboardingRequestView(
                        rs.getString("request_public_id"),
                        rs.getString("hospital_name"),
                        rs.getString("city"),
                        rs.getString("facility_type"),
                        rs.getString("request_status"),
                        rs.getString("contact_name"),
                        rs.getString("contact_mobile"),
                        rs.getString("contact_email"),
                        rs.getTimestamp("requested_at").toLocalDateTime()
                )
        );
        return new PlatformAdminDtos.PlatformOnboardingCollection(requests);
    }

    private long queryCount(String sql) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class);
        return value == null ? 0 : value;
    }
}