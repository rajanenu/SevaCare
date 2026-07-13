package com.sevacare.tenant.service;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.cache.annotation.CacheEvict;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.PlatformAdminDtos;
import com.sevacare.shared.event.PharmacyEnabledEvent;
import com.sevacare.tenant.capability.TenantKind;
import com.sevacare.tenant.capability.TenantModuleService;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;
import com.sevacare.tenant.terms.TermsService;

@Service
public class PlatformAdminService {

    public static final String PLATFORM_TENANT_PUBLIC_ID = "platform";

    private final TenantRegistryRepository tenantRegistryRepository;
    private final JdbcTemplate jdbcTemplate;
    private final TenantRegistryService tenantRegistryService;

    private final TenantModuleService tenantModuleService;
    private final TermsService termsService;
    private final ApplicationEventPublisher events;

    public PlatformAdminService(
            TenantRegistryRepository tenantRegistryRepository,
            JdbcTemplate jdbcTemplate,
            TenantRegistryService tenantRegistryService,
            TenantModuleService tenantModuleService,
            TermsService termsService,
            ApplicationEventPublisher events
    ) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.jdbcTemplate = jdbcTemplate;
        this.tenantRegistryService = tenantRegistryService;
        this.tenantModuleService = tenantModuleService;
        this.termsService = termsService;
        this.events = events;
    }

    @Transactional(readOnly = true)
    public PlatformAdminDtos.PharmacyProfileCollection pharmacyProfiles() {
        return new PlatformAdminDtos.PharmacyProfileCollection(
                tenantModuleService.pharmacyProfiles().stream()
                        .map(p -> new PlatformAdminDtos.PharmacyProfileOptionView(
                                p.profileKey(), p.displayName(), p.description()))
                        .toList());
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
    public boolean hasActivePlatformAdminByMobile(String mobileNumber) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM public.platform_admin_user WHERE active = true AND mobile_number = ?",
                Integer.class,
                mobileNumber
        );
        return count != null && count > 0;
    }

    @Transactional(readOnly = true)
    public String findPlatformAdminPublicIdByMobile(String mobileNumber) {
        String subjectPublicId = jdbcTemplate.query(
                """
                SELECT platform_admin_public_id
                FROM public.platform_admin_user
                WHERE active = true AND mobile_number = ?
                ORDER BY created_at ASC, platform_admin_public_id ASC
                LIMIT 1
                """,
                rs -> rs.next() ? rs.getString("platform_admin_public_id") : null,
                mobileNumber
        );

        if (subjectPublicId == null || subjectPublicId.isBlank()) {
            throw new IllegalArgumentException("No active platform admin exists for mobile number");
        }

        return subjectPublicId;
    }

    @Transactional(readOnly = true)
    public String findPlatformAdminNameByMobile(String mobileNumber) {
        String name = jdbcTemplate.query(
                """
                SELECT full_name
                FROM public.platform_admin_user
                WHERE active = true AND mobile_number = ?
                ORDER BY created_at ASC, platform_admin_public_id ASC
                LIMIT 1
                """,
                rs -> rs.next() ? rs.getString("full_name") : null,
                mobileNumber
        );
        return name != null ? name : "Platform Admin";
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
                .filter(tenant -> !PLATFORM_TENANT_PUBLIC_ID.equalsIgnoreCase(tenant.getTenantPublicId()))
                .sorted(Comparator.comparing(TenantRegistry::getTenantPublicId))
                .map(this::toTenantView)
                .toList();
        return new PlatformAdminDtos.PlatformTenantCollection(tenants);
    }

    @Transactional
    public PlatformAdminDtos.PlatformTenantView createTenant(PlatformAdminDtos.PlatformTenantUpsertRequest request) {
        // Contact mobile is mandatory: it becomes the tenant's first admin login,
        // whether that admin runs a hospital or a medical store.
        String contactMobile = normalizeNullable(request.contactMobile());
        if (contactMobile == null) {
            throw new IllegalArgumentException("Contact mobile number is required — it becomes the admin login.");
        }

        // Throws with a readable message when both boxes are unticked.
        TenantKind kind = TenantKind.of(request.clinicalEnabled(), request.pharmacyEnabled());
        String profileKey = request.pharmacyEnabled() ? normalizeNullable(request.pharmacyProfileKey()) : null;

        String tenantPublicId = tenantRegistryService.nextTenantPublicId();
        TenantRegistry tenant = tenantRegistryService.provisionTenant(
                tenantPublicId,
                request.hospitalName().trim(),
                normalizeThemeKey(request.themeKey()),
                defaultContactName(request.contactName(), request.hospitalName()),
                contactMobile,
                normalizeNullable(request.contactEmail()),
                normalizeNullable(request.city()),
                normalizeNullable(request.pinCode()),
                kind,
                profileKey
        );

        // The customer read SevaCare's terms and agreed before we opened the account.
        // Recorded against the tenant so their admin is not asked the same question
        // again at first sign-in — and so we can still answer, years later, what they
        // agreed to and when. Left unticked, the app asks them itself.
        if (request.termsAcceptedAtOnboarding()) {
            termsService.stampOnboardingAcceptance(
                    tenant,
                    defaultContactName(request.contactName(), request.hospitalName()) + " (at onboarding)");
            tenant = tenantRegistryRepository.save(tenant);
        }
        return toTenantView(tenant);
    }

    /**
     * Suspending a tenant here is how a customer is cut off — for non-payment, at
     * offboarding, or after a breach. The status is read through the
     * {@code tenantSchemas} cache, so evict it or this instance keeps serving them.
     * The eviction is local to this JVM; the cache's TTL is what makes the other
     * Cloud Run instances catch up (see PlatformConfiguration).
     */
    @CacheEvict(cacheNames = "tenantSchemas", key = "#tenantPublicId")
    @Transactional
    public PlatformAdminDtos.PlatformTenantView updateTenant(
            String tenantPublicId,
            PlatformAdminDtos.PlatformTenantUpsertRequest request
    ) {
        TenantRegistry tenant = findTenant(tenantPublicId);
        tenant.setTenantName(request.hospitalName().trim());
        tenant.setTenantThemeKey(normalizeThemeKey(request.themeKey()));
        tenant.setTenantStatus(normalizeStatus(request.status()));
        if (request.city() != null) tenant.setCity(request.city().trim());
        if (request.pinCode() != null) tenant.setPinCode(request.pinCode().trim());

        // Adding a pharmacy to a hospital a year later is the expected path, so it
        // is the same request that renamed it. Removing one is guarded: a stock
        // ledger is a retained record, and unticking a box must never be how it
        // vanishes from the product. assertSafeToDisable throws with the reason.
        TenantKind kind = TenantKind.of(request.clinicalEnabled(), request.pharmacyEnabled());
        String profileKey = request.pharmacyEnabled()
                ? firstNonBlank(normalizeNullable(request.pharmacyProfileKey()),
                                tenant.getPharmacyProfileKey(),
                                kind.pharmacyProfileKey())
                : null;

        tenantModuleService.assertSafeToDisable(
                tenantPublicId,
                tenantModuleService.manifestOf(tenantPublicId),
                request.clinicalEnabled(),
                request.pharmacyEnabled());

        tenant.setClinicalEnabled(request.clinicalEnabled());
        tenant.setPharmacyProfileKey(profileKey);

        TenantRegistry saved = tenantRegistryRepository.save(tenant);
        syncHospitalAdmin(saved, request.contactName(), request.contactMobile(), request.contactEmail());

        // The hospital that just bought a pharmacy needs a shelf, same as a store
        // that opened with one. Re-announcing it for a tenant that already had
        // pharmacy on is harmless — the seeder leaves a stocked store alone.
        if (profileKey != null) {
            events.publishEvent(new PharmacyEnabledEvent(
                    saved.getTenantPublicId(), saved.getTenantSchemaName()));
        }
        return toTenantView(saved);
    }

    @Transactional
    public void updateTenantHeroImage(String tenantPublicId, PlatformAdminDtos.PlatformTenantHeroImageRequest request) {
        String imageBase64 = request.imageBase64();
        if (imageBase64 != null && imageBase64.length() > 4_000_000) {
            throw new IllegalArgumentException("Hero image too large — please upload an image under ~3 MB.");
        }
        findTenant(tenantPublicId); // 404 semantics for unknown tenants
        tenantRegistryService.updateTenantHeroImage(tenantPublicId, imageBase64, request.contentType());
    }

    @CacheEvict(cacheNames = "tenantSchemas", key = "#tenantPublicId")
    @Transactional
    public String deleteTenant(String tenantPublicId) {
        TenantRegistry tenant = findTenant(tenantPublicId);
        // Delete FK-constrained rows first (order matters)
        jdbcTemplate.update("DELETE FROM public.doctor_hospital_enrollment WHERE tenant_public_id = ?", tenantPublicId);
        jdbcTemplate.update(
            "DELETE FROM public.tenant_onboarding_document WHERE request_public_id IN (" +
                "SELECT request_public_id FROM public.tenant_onboarding_request WHERE lower(trim(hospital_name)) = lower(trim(?))" +
                ")",
            tenant.getTenantName()
        );
        jdbcTemplate.update(
            "DELETE FROM public.tenant_onboarding_request WHERE lower(trim(hospital_name)) = lower(trim(?))",
            tenant.getTenantName()
        );
        jdbcTemplate.update("DELETE FROM public.hospital_qrcode WHERE tenant_public_id = ?", tenantPublicId);
        jdbcTemplate.execute("DROP SCHEMA IF EXISTS " + safeSchemaName(tenant.getTenantSchemaName()) + " CASCADE");
        tenantRegistryRepository.delete(tenant);
        return tenantPublicId;
    }

    @Transactional(readOnly = true)
    public PlatformAdminDtos.PlatformOnboardingCollection listOnboardingRequests() {
        List<PlatformAdminDtos.PlatformOnboardingRequestView> requests = jdbcTemplate.query(
                """
                SELECT request_public_id, hospital_name, city, facility_type, request_status,
                       contact_name, contact_mobile, contact_email, requested_at
                FROM public.tenant_onboarding_request
                  WHERE request_status = 'submitted'
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

    @Transactional
    public PlatformAdminDtos.PlatformTenantQrCodeView generateOrGetTenantQrCode(String tenantPublicId) {
        if (PLATFORM_TENANT_PUBLIC_ID.equalsIgnoreCase(tenantPublicId)) {
            throw new IllegalArgumentException("Platform tenant does not support patient QR flow");
        }

        TenantRegistry tenant = tenantRegistryRepository.findByTenantPublicIdAndTenantStatus(tenantPublicId, "active")
                .orElseThrow(() -> new IllegalArgumentException("Active tenant not found: " + tenantPublicId));

        var existing = jdbcTemplate.query(
                "SELECT qrcode_public_id, qrcode_uuid FROM public.hospital_qrcode WHERE tenant_public_id = ? LIMIT 1",
                (rs, rowNum) -> new PlatformAdminDtos.PlatformTenantQrCodeView(
                        rs.getString("qrcode_public_id"),
                        tenant.getTenantPublicId(),
                        rs.getString("qrcode_uuid")
                ),
                tenant.getTenantPublicId()
        );

        if (!existing.isEmpty()) {
            return existing.get(0);
        }

        String qrcodePublicId = "QR-" + ThreadLocalRandom.current().nextInt(1000, 99999);
        String qrcodeUuid = UUID.randomUUID().toString();

        jdbcTemplate.update(
                "INSERT INTO public.hospital_qrcode (qrcode_public_id, tenant_public_id, qrcode_uuid, created_at) VALUES (?, ?, ?, ?)",
                qrcodePublicId,
                tenant.getTenantPublicId(),
                qrcodeUuid,
                LocalDateTime.now()
        );

        return new PlatformAdminDtos.PlatformTenantQrCodeView(qrcodePublicId, tenant.getTenantPublicId(), qrcodeUuid);
    }

    @Transactional(readOnly = true)
    public PlatformAdminDtos.PlatformAdminUserCollection listPlatformAdmins(boolean activeOnly) {
        String sql = activeOnly
                ? """
                  SELECT platform_admin_public_id, full_name, mobile_number, email, active, created_at
                  FROM public.platform_admin_user
                  WHERE active = true
                  ORDER BY created_at DESC, platform_admin_public_id DESC
                  """
                : """
                  SELECT platform_admin_public_id, full_name, mobile_number, email, active, created_at
                  FROM public.platform_admin_user
                  ORDER BY created_at DESC, platform_admin_public_id DESC
                  """;

        List<PlatformAdminDtos.PlatformAdminUserView> admins = jdbcTemplate.query(
                sql,
                (rs, rowNum) -> new PlatformAdminDtos.PlatformAdminUserView(
                        rs.getString("platform_admin_public_id"),
                        rs.getString("full_name"),
                        rs.getString("mobile_number"),
                        rs.getString("email"),
                        rs.getBoolean("active"),
                        rs.getTimestamp("created_at").toLocalDateTime()
                )
        );
        return new PlatformAdminDtos.PlatformAdminUserCollection(admins);
    }

    @Transactional(readOnly = true)
    public PlatformAdminDtos.PlatformAdminUserView getPlatformAdmin(String platformAdminPublicId) {
        return jdbcTemplate.query(
                """
                SELECT platform_admin_public_id, full_name, mobile_number, email, active, created_at
                FROM public.platform_admin_user
                WHERE platform_admin_public_id = ?
                """,
                rs -> rs.next()
                        ? new PlatformAdminDtos.PlatformAdminUserView(
                                rs.getString("platform_admin_public_id"),
                                rs.getString("full_name"),
                                rs.getString("mobile_number"),
                                rs.getString("email"),
                                rs.getBoolean("active"),
                                rs.getTimestamp("created_at").toLocalDateTime()
                        )
                        : null,
                platformAdminPublicId
        );
    }

    @Transactional
    public PlatformAdminDtos.PlatformAdminUserView createPlatformAdmin(PlatformAdminDtos.PlatformAdminUserUpsertRequest request) {
        String publicId = nextPlatformAdminPublicId();
        boolean active = request.active() == null || request.active();
        jdbcTemplate.update(
                """
                INSERT INTO public.platform_admin_user (
                    platform_admin_public_id, full_name, mobile_number, email, active
                ) VALUES (?, ?, ?, ?, ?)
                """,
                publicId,
                request.fullName(),
                request.mobileNumber(),
                request.email(),
                active
        );
        return getPlatformAdmin(publicId);
    }

    @Transactional
    public PlatformAdminDtos.PlatformAdminUserView updatePlatformAdmin(
            String platformAdminPublicId,
            PlatformAdminDtos.PlatformAdminUserUpsertRequest request
    ) {
        boolean active = request.active() == null || request.active();
        int updated = jdbcTemplate.update(
                """
                UPDATE public.platform_admin_user
                SET full_name = ?, mobile_number = ?, email = ?, active = ?
                WHERE platform_admin_public_id = ?
                """,
                request.fullName(),
                request.mobileNumber(),
                request.email(),
                active,
                platformAdminPublicId
        );

        if (updated == 0) {
            throw new IllegalArgumentException("Platform admin not found: " + platformAdminPublicId);
        }
        return getPlatformAdmin(platformAdminPublicId);
    }

    @Transactional
    public PlatformAdminDtos.PlatformAdminUserView deactivatePlatformAdmin(String platformAdminPublicId) {
        int updated = jdbcTemplate.update(
                "UPDATE public.platform_admin_user SET active = false WHERE platform_admin_public_id = ?",
                platformAdminPublicId
        );
        if (updated == 0) {
            throw new IllegalArgumentException("Platform admin not found: " + platformAdminPublicId);
        }
        return getPlatformAdmin(platformAdminPublicId);
    }

    /**
     * Self-service "delete my account". Only disables login — nothing this
     * platform admin created or approved is touched.
     */
    @Transactional
    public void requestAccountDeletion(String platformAdminPublicId) {
        int updated = jdbcTemplate.update(
                "UPDATE public.platform_admin_user SET active = false, deletion_requested_at = ? WHERE platform_admin_public_id = ?",
                LocalDateTime.now(),
                platformAdminPublicId
        );
        if (updated == 0) {
            throw new IllegalArgumentException("Platform admin not found: " + platformAdminPublicId);
        }
    }

    @Transactional
    public String deletePlatformAdmin(String platformAdminPublicId) {
        int deleted = jdbcTemplate.update(
                "DELETE FROM public.platform_admin_user WHERE platform_admin_public_id = ?",
                platformAdminPublicId
        );
        if (deleted == 0) {
            throw new IllegalArgumentException("Platform admin not found: " + platformAdminPublicId);
        }
        return platformAdminPublicId;
    }

    @Transactional(readOnly = true)
    public String nextPlatformAdminPublicId() {
        int candidate = ThreadLocalRandom.current().nextInt(1002, 9999);
        String publicId = "PA-" + candidate;
        Integer exists = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM public.platform_admin_user WHERE platform_admin_public_id = ?",
                Integer.class,
                publicId
        );
        if (exists != null && exists > 0) {
            return "PA-" + ThreadLocalRandom.current().nextInt(10000, 99999);
        }
        return publicId;
    }

    private long queryCount(String sql) {
        Long value = jdbcTemplate.queryForObject(sql, Long.class);
        return value == null ? 0 : value;
    }

    private PlatformAdminDtos.PlatformTenantView toTenantView(TenantRegistry tenant) {
        boolean pharmacy = tenant.getPharmacyProfileKey() != null;
        return new PlatformAdminDtos.PlatformTenantView(
                tenant.getTenantPublicId(),
                tenant.getTenantName(),
                tenant.getCity(),
                tenant.getPinCode(),
                tenant.getTenantThemeKey(),
                tenant.getTenantSchemaName(),
                tenant.getTenantStatus(),
                tenant.isClinicalEnabled(),
                tenant.getPharmacyProfileKey(),
                TenantKind.of(tenant.isClinicalEnabled(), pharmacy).displayName()
        );
    }

    /**
     * Keeps a tenant's existing pharmacy profile when the caller sends none: a
     * platform admin editing a hospital's city must not silently demote its
     * PHARMACY_CHAIN to the CLINIC_DISPENSARY default.
     */
    private static String firstNonBlank(String... candidates) {
        for (String candidate : candidates) {
            if (candidate != null && !candidate.isBlank()) {
                return candidate.trim();
            }
        }
        return null;
    }

    private TenantRegistry findTenant(String tenantPublicId) {
        if (PLATFORM_TENANT_PUBLIC_ID.equalsIgnoreCase(tenantPublicId)) {
            throw new IllegalArgumentException("Platform tenant cannot be modified");
        }
        return tenantRegistryRepository.findById(tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Tenant not found: " + tenantPublicId));
    }

    private void syncHospitalAdmin(TenantRegistry tenant, String contactName, String contactMobile, String contactEmail) {
        String mobile = normalizeNullable(contactMobile);
        if (mobile == null) {
            return;
        }

        String schemaName = safeSchemaName(tenant.getTenantSchemaName());
        String adminPublicId = jdbcTemplate.query(
                "SELECT admin_public_id FROM " + schemaName + ".admin_user ORDER BY created_at ASC, admin_public_id ASC LIMIT 1",
                rs -> rs.next() ? rs.getString("admin_public_id") : null
        );

        String name = defaultContactName(contactName, tenant.getTenantName());
        String email = normalizeNullable(contactEmail);

        if (adminPublicId == null || adminPublicId.isBlank()) {
            jdbcTemplate.update(
                    "INSERT INTO " + schemaName + ".admin_user (admin_public_id, tenant_public_id, mobile_number, email, name, full_name, active) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    tenantRegistryService.nextAdminPublicId(),
                    tenant.getTenantPublicId(),
                    mobile,
                    email,
                    name,
                    name,
                    true
            );
            return;
        }

        jdbcTemplate.update(
                "UPDATE " + schemaName + ".admin_user SET mobile_number = ?, email = ?, name = ?, full_name = ?, active = ? WHERE admin_public_id = ?",
                mobile,
                email,
                name,
                name,
                "active".equalsIgnoreCase(tenant.getTenantStatus()),
                adminPublicId
        );
    }

    private String defaultContactName(String contactName, String hospitalName) {
        String normalized = normalizeNullable(contactName);
        return normalized != null ? normalized : hospitalName.trim() + " Admin";
    }

    private String normalizeThemeKey(String themeKey) {
        String normalized = normalizeNullable(themeKey);
        return normalized == null ? "default" : normalized.toLowerCase(Locale.ROOT);
    }

    private String normalizeStatus(String status) {
        String normalized = normalizeNullable(status);
        if (normalized == null) {
            return "active";
        }
        String value = normalized.toLowerCase(Locale.ROOT);
        if (!"active".equals(value) && !"inactive".equals(value)) {
            throw new IllegalArgumentException("Unsupported tenant status: " + status);
        }
        return value;
    }

    private String normalizeNullable(String value) {
        if (value == null) {
            return null;
        }
        String normalized = value.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private String safeSchemaName(String schemaName) {
        if (schemaName == null || !schemaName.matches("[A-Za-z0-9_]+")) {
            throw new IllegalArgumentException("Invalid schema name");
        }
        return schemaName;
    }
}