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
    private final TenantSchemaMaintenanceService schemaMaintenanceService;

    public TenantRegistryService(
            TenantRegistryRepository tenantRegistryRepository,
            JdbcTemplate jdbcTemplate,
            TenantSchemaMaintenanceService schemaMaintenanceService
    ) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.jdbcTemplate = jdbcTemplate;
        this.schemaMaintenanceService = schemaMaintenanceService;
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
        jdbcTemplate.execute("CREATE SCHEMA IF NOT EXISTS " + schemaName);
        createTenantSchema(schemaName);

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
        tenantRegistryRepository.save(tenant);

        // Repair schema shape immediately — a hospital onboarded while the server
        // keeps running (no restart) must work from the first request, not just
        // after the next boot-time sweep (TenantAdminSchemaInitializer).
        schemaMaintenanceService.ensureSchemaShape(tenant, schemaName);

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

    private void createTenantSchema(String schemaName) {
        // Create tables following the pattern from bootstrap migration
        String tenantSchemaDdl = """
            CREATE TABLE IF NOT EXISTS %s.patient (
                patient_public_id VARCHAR(24) PRIMARY KEY,
                tenant_public_id VARCHAR(24) NOT NULL,
                full_name VARCHAR(160) NOT NULL,
                mobile_number VARCHAR(24) NOT NULL,
                email VARCHAR(160),
                age INT,
                gender VARCHAR(24),
                address TEXT,
                status VARCHAR(24) DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                deletion_requested_at TIMESTAMP,
                photo_base64 TEXT
            );

            CREATE TABLE IF NOT EXISTS %s.doctor (
                doctor_public_id VARCHAR(24) PRIMARY KEY,
                tenant_public_id VARCHAR(24) NOT NULL,
                full_name VARCHAR(160) NOT NULL,
                specialty VARCHAR(120),
                availability VARCHAR(160),
                fee VARCHAR(24),
                mobile_number VARCHAR(24),
                active BOOLEAN DEFAULT true,
                age INT,
                address VARCHAR(160),
                about_me TEXT,
                available_from DATE,
                ready_to_look_patients BOOLEAN DEFAULT true,
                booking_mode VARCHAR(16) NOT NULL DEFAULT 'BOTH',
                experience_years INT,
                qualification VARCHAR(200),
                deletion_requested_at TIMESTAMP,
                photo_base64 TEXT
            );
            
            CREATE TABLE IF NOT EXISTS %s.doctor_details (
                doctor_public_id VARCHAR(24) PRIMARY KEY,
                tenant_public_id VARCHAR(24) NOT NULL,
                mobile_number VARCHAR(24),
                age INT,
                gender VARCHAR(24),
                license_number VARCHAR(80),
                experience_years INT,
                address VARCHAR(160),
                city VARCHAR(120),
                state VARCHAR(120),
                FOREIGN KEY (doctor_public_id) REFERENCES %s.doctor(doctor_public_id)
            );
            
            CREATE TABLE IF NOT EXISTS %s.doctor_schedule (
                schedule_public_id VARCHAR(24) PRIMARY KEY,
                doctor_public_id VARCHAR(24) NOT NULL,
                tenant_public_id VARCHAR(24) NOT NULL,
                appointment_interval_minutes INT,
                lunch_break_start_time VARCHAR(24),
                lunch_break_end_time VARCHAR(24),
                max_appointments_per_day INT,
                working_days VARCHAR(200),
                clinic_start_time VARCHAR(24),
                clinic_end_time VARCHAR(24),
                FOREIGN KEY (doctor_public_id) REFERENCES %s.doctor(doctor_public_id)
            );
            
            CREATE TABLE IF NOT EXISTS %s.appointment (
                appointment_public_id VARCHAR(24) PRIMARY KEY,
                tenant_public_id VARCHAR(24) NOT NULL,
                patient_public_id VARCHAR(24) NOT NULL,
                doctor_public_id VARCHAR(24) NOT NULL,
                appointment_date DATE,
                appointment_slot VARCHAR(80),
                appointment_status VARCHAR(24) DEFAULT 'upcoming',
                notes TEXT,
                consultation_fee INTEGER DEFAULT 0,
                vitals_summary VARCHAR(1000),
                booking_type VARCHAR(16) NOT NULL DEFAULT 'SLOT',
                token_number INTEGER,
                token_session VARCHAR(16),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (patient_public_id) REFERENCES %s.patient(patient_public_id),
                FOREIGN KEY (doctor_public_id) REFERENCES %s.doctor(doctor_public_id)
            );
            
            CREATE TABLE IF NOT EXISTS %s.prescription (
                prescription_public_id VARCHAR(24) PRIMARY KEY,
                tenant_public_id VARCHAR(24) NOT NULL,
                appointment_public_id VARCHAR(24),
                patient_public_id VARCHAR(24) NOT NULL,
                doctor_public_id VARCHAR(24) NOT NULL,
                doctor_name VARCHAR(120),
                issued_on VARCHAR(20),
                prescription_date DATE,
                notes TEXT,
                valid_until DATE,
                file_url VARCHAR(500),
                status VARCHAR(20) DEFAULT 'active',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (patient_public_id) REFERENCES %s.patient(patient_public_id),
                FOREIGN KEY (doctor_public_id) REFERENCES %s.doctor(doctor_public_id)
            );
            
            CREATE TABLE IF NOT EXISTS %s.prescription_medicine (
                id BIGSERIAL PRIMARY KEY,
                prescription_public_id VARCHAR(24) NOT NULL,
                medicine_name VARCHAR(255),
                strength VARCHAR(100),
                frequency VARCHAR(255),
                duration VARCHAR(100),
                instructions TEXT,
                created_at TIMESTAMP NOT NULL DEFAULT NOW(),
                FOREIGN KEY (prescription_public_id) REFERENCES %s.prescription(prescription_public_id)
            );
            
            CREATE TABLE IF NOT EXISTS %s.medical_history (
                id BIGSERIAL PRIMARY KEY,
                patient_public_id VARCHAR(24) NOT NULL,
                tenant_public_id VARCHAR(24) NOT NULL,
                record_type VARCHAR(50),
                record_value VARCHAR(255) NOT NULL DEFAULT '',
                notes TEXT,
                record_date DATE,
                created_at TIMESTAMP NOT NULL DEFAULT NOW(),
                FOREIGN KEY (patient_public_id) REFERENCES %s.patient(patient_public_id)
            );
            
            CREATE TABLE IF NOT EXISTS %s.doctor_license_metadata (
                license_public_id VARCHAR(24) PRIMARY KEY,
                doctor_public_id VARCHAR(24),
                tenant_public_id VARCHAR(24),
                license_number VARCHAR(80),
                issuing_authority VARCHAR(160),
                issue_date DATE,
                expiry_date DATE
            );
            
            CREATE TABLE IF NOT EXISTS %s.admin_user (
                admin_public_id VARCHAR(24) PRIMARY KEY,
                tenant_public_id VARCHAR(24) NOT NULL,
                mobile_number VARCHAR(24),
                email VARCHAR(160),
                name VARCHAR(160),
                full_name VARCHAR(160),
                active BOOLEAN DEFAULT true,
                user_type VARCHAR(16) DEFAULT 'ADMIN',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                deletion_requested_at TIMESTAMP,
                photo_base64 TEXT
            );

            CREATE TABLE IF NOT EXISTS %s.token_counter (
                tenant_public_id  VARCHAR(24) NOT NULL,
                doctor_public_id  VARCHAR(24) NOT NULL,
                token_date        DATE        NOT NULL,
                session           VARCHAR(16) NOT NULL,
                last_token        INTEGER     NOT NULL DEFAULT 0,
                PRIMARY KEY (tenant_public_id, doctor_public_id, token_date, session)
            );

            CREATE TABLE IF NOT EXISTS %s.doctor_review (
                id BIGSERIAL PRIMARY KEY,
                appointment_public_id VARCHAR(16) NOT NULL UNIQUE,
                doctor_public_id VARCHAR(16) NOT NULL,
                patient_public_id VARCHAR(16) NOT NULL,
                rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
                comment VARCHAR(1000),
                created_at TIMESTAMP NOT NULL DEFAULT now()
            );
            """;

        jdbcTemplate.execute(tenantSchemaDdl.replace("%s", schemaName));
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
