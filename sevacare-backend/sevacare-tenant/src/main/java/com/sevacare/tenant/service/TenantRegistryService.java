package com.sevacare.tenant.service;

import java.util.List;
import java.util.Locale;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.sevacare.shared.dto.DiscoveryDtos;
import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;

@Service
public class TenantRegistryService {

    private final TenantRegistryRepository tenantRegistryRepository;
    private final JdbcTemplate jdbcTemplate;
    private final TenantMigrationService tenantMigrationService;

    public TenantRegistryService(
            TenantRegistryRepository tenantRegistryRepository,
            JdbcTemplate jdbcTemplate,
            TenantMigrationService tenantMigrationService
    ) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.jdbcTemplate = jdbcTemplate;
        this.tenantMigrationService = tenantMigrationService;
    }

    @Transactional(readOnly = true)
    public List<DiscoveryDtos.TenantSummary> listTenantSummaries() {
        return tenantRegistryRepository.findByTenantStatus("active")
                .stream()
                .map(tenant -> new DiscoveryDtos.TenantSummary(
                        tenant.getTenantPublicId(),
                        tenant.getTenantName(),
                        tenant.getCity().isBlank() ? "Unknown city" : tenant.getCity(),
                        "General medicine",
                        tenant.getTenantThemeKey(),
                        tenant.getPinCode().isBlank() ? null : tenant.getPinCode()
                ))
                .toList();
    }

    /**
     * Hero image queried via JdbcTemplate (not the entity) so tenant list /
     * schema-resolution paths never load the large base64 column.
     */
    @Transactional(readOnly = true)
    public DiscoveryDtos.TenantHeroImage getTenantHeroImage(String tenantPublicId) {
        return jdbcTemplate.query(
                "SELECT hero_image_base64, hero_image_content_type FROM public.tenant_registry " +
                        "WHERE tenant_public_id = ? AND tenant_status = 'active'",
                rs -> rs.next()
                        ? new DiscoveryDtos.TenantHeroImage(
                                tenantPublicId,
                                rs.getString("hero_image_base64"),
                                rs.getString("hero_image_content_type"))
                        : new DiscoveryDtos.TenantHeroImage(tenantPublicId, null, null),
                tenantPublicId
        );
    }

    @Transactional
    public void updateTenantHeroImage(String tenantPublicId, String imageBase64, String contentType) {
        boolean clearing = imageBase64 == null || imageBase64.isBlank();
        int updated = jdbcTemplate.update(
                "UPDATE public.tenant_registry SET hero_image_base64 = ?, hero_image_content_type = ? " +
                        "WHERE tenant_public_id = ?",
                clearing ? null : imageBase64,
                clearing ? null : contentType,
                tenantPublicId
        );
        if (updated == 0) {
            throw new IllegalArgumentException("Unknown tenant: " + tenantPublicId);
        }
    }

    @Transactional(readOnly = true)
    @Cacheable("tenantSchemas")
    public String resolveTenantSchema(String tenantPublicId) {
        TenantRegistry tenant = tenantRegistryRepository.findByTenantPublicIdAndTenantStatus(tenantPublicId, "active")
                .orElseThrow(() -> new IllegalArgumentException("Unknown tenant: " + tenantPublicId));
        return tenant.getTenantSchemaName();
    }

    @Transactional(readOnly = true)
    public TenantRegistry mustFindActiveTenant(String tenantPublicId) {
        return tenantRegistryRepository.findByTenantPublicIdAndTenantStatus(tenantPublicId, "active")
                .orElseThrow(() -> new IllegalArgumentException("Unknown tenant: " + tenantPublicId));
    }

    public String nextTenantPublicId() {
        return nextPrefixedId("T", "tenant_public_id_seq");
    }

    public String nextPatientPublicId() {
        return nextPrefixedId("P", "patient_public_id_seq");
    }

    public String nextDoctorPublicId() {
        return nextPrefixedId("D", "doctor_public_id_seq");
    }

    public String nextAdminPublicId() {
        return nextPrefixedId("A", "admin_public_id_seq");
    }

    public String buildTenantSchemaName(String tenantPublicId) {
        return "tenant_t_" + tenantPublicId.split("-")[1].toLowerCase(Locale.ROOT);
    }

    @Transactional
    public TenantRegistry provisionTenant(
            String tenantPublicId,
            String hospitalName,
            String themeKey,
            String contactName,
            String contactMobile,
            String contactEmail
    ) {
        return provisionTenant(tenantPublicId, hospitalName, themeKey, contactName, contactMobile, contactEmail, null, null);
    }

    @Transactional
    public TenantRegistry provisionTenant(
            String tenantPublicId,
            String hospitalName,
            String themeKey,
            String contactName,
            String contactMobile,
            String contactEmail,
            String city,
            String pinCode
    ) {
        String schemaName = buildTenantSchemaName(tenantPublicId);

        TenantRegistry tenant = new TenantRegistry();
        tenant.setTenantPublicId(tenantPublicId);
        tenant.setTenantName(hospitalName);
        tenant.setTenantThemeKey(themeKey);
        tenant.setTenantSchemaName(schemaName);
        tenant.setTenantStatus("active");
        if (city != null && !city.isBlank()) {
            tenant.setCity(city.trim());
        }
        if (pinCode != null && !pinCode.isBlank()) {
            tenant.setPinCode(pinCode.trim());
        }
        if (contactEmail != null && !contactEmail.isBlank()) {
            tenant.setEmail(contactEmail.trim());
        }

        // Create and migrate the schema before the registry row exists, so a
        // hospital onboarded while the server keeps running works from its first
        // request rather than after the next boot sweep. Flyway commits on its own
        // connection: if the save below rolls back, an empty schema is left behind,
        // which the next attempt reuses rather than trips over.
        tenantMigrationService.migrate(tenant);

        tenantRegistryRepository.save(tenant);

        if (contactMobile != null && !contactMobile.isBlank()) {
            seedHospitalAdmin(schemaName, tenantPublicId, contactName, contactMobile, contactEmail);
        }

        return tenant;
    }

    @Transactional(readOnly = true)
    public String getTenantEmail(String tenantPublicId) {
        return tenantRegistryRepository.findById(tenantPublicId)
                .map(TenantRegistry::getEmail)
                .orElseThrow(() -> new IllegalArgumentException("Tenant not found: " + tenantPublicId));
    }

    @Transactional
    public void updateTenantEmail(String tenantPublicId, String email) {
        TenantRegistry tenant = tenantRegistryRepository.findById(tenantPublicId)
                .orElseThrow(() -> new IllegalArgumentException("Tenant not found: " + tenantPublicId));
        tenant.setEmail(email == null ? null : email.trim());
        tenantRegistryRepository.save(tenant);
    }

    @Transactional
    public String submitOnboardingRequest(
            String hospitalName,
            String licenseNumber,
            String state,
            String city,
            String address,
            String country,
            String contactName,
            String contactMobile,
            String contactEmail,
            String supportingDocs,
            String facilityType,
            String pinCode
    ) {
        String requestPublicId = nextPrefixedId("ONB", "onboarding_request_public_id_seq");
        jdbcTemplate.update(
                """
                INSERT INTO public.tenant_onboarding_request
                    (request_public_id, hospital_name, license_number, address, city, state, country, contact_name, contact_mobile, contact_email, supporting_docs, facility_type, request_status)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'submitted')
                """,
                requestPublicId,
                hospitalName,
                licenseNumber,
                address,
                city,
                state,
                country,
                contactName,
                contactMobile,
                contactEmail,
                supportingDocs,
                facilityType
        );
        
        // Auto-activate: Create tenant and schema for immediate access
        try {
            String tenantPublicId = nextTenantPublicId();
            provisionTenant(tenantPublicId, hospitalName, "default", contactName, contactMobile, contactEmail, city, pinCode);
            
            // Update onboarding request to approved
            jdbcTemplate.update(
                    "UPDATE public.tenant_onboarding_request SET request_status = 'approved' WHERE request_public_id = ?",
                    requestPublicId
            );
        } catch (Exception e) {
            // Log error but don't fail the onboarding submission
            System.err.println("Warning: Failed to auto-activate tenant: " + e.getMessage());
        }
        
        return requestPublicId;
    }

    /**
     * Seed the hospital's first admin using the contact mobile the hospital
     * provided at onboarding — that number IS the Hospital Admin login. Once
     * logged in, this admin can create further admins from the admin dashboard.
     * (The old "generic temp admin" 9000000003 flow has been removed.)
     */
    private void seedHospitalAdmin(String schemaName, String tenantPublicId, String contactName, String contactMobile, String contactEmail) {
        Integer existingContact = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schemaName + ".admin_user WHERE mobile_number = ?",
                Integer.class, contactMobile);
        if (existingContact == null || existingContact == 0) {
            jdbcTemplate.update(
                    "INSERT INTO " + schemaName + ".admin_user (admin_public_id, tenant_public_id, mobile_number, email, name, full_name, active, user_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                    nextAdminPublicId(), tenantPublicId, contactMobile, contactEmail, contactName, contactName, true, "ADMIN"
            );
        }
    }

    private String nextPrefixedId(String prefix, String sequenceName) {
        Long value = jdbcTemplate.queryForObject("SELECT nextval('public." + sequenceName + "')", Long.class);
        if (value == null) {
            throw new IllegalStateException("Could not generate id for " + prefix);
        }
        return prefix + "-" + String.format("%04d", value);
    }
}
