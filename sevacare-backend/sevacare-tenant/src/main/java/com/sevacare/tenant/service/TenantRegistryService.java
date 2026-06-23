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

    public TenantRegistryService(TenantRegistryRepository tenantRegistryRepository, JdbcTemplate jdbcTemplate) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Transactional(readOnly = true)
    public List<DiscoveryDtos.TenantSummary> listTenantSummaries() {
        return tenantRegistryRepository.findByTenantStatus("active")
                .stream()
                .map(tenant -> new DiscoveryDtos.TenantSummary(
                        tenant.getTenantPublicId(),
                        tenant.getTenantName(),
                        "Unknown city",
                        "General medicine",
                        tenant.getTenantThemeKey()
                ))
                .toList();
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
        String schemaName = buildTenantSchemaName(tenantPublicId);
        jdbcTemplate.execute("CREATE SCHEMA IF NOT EXISTS " + schemaName);
        createTenantSchema(schemaName);

        TenantRegistry tenant = new TenantRegistry();
        tenant.setTenantPublicId(tenantPublicId);
        tenant.setTenantName(hospitalName);
        tenant.setTenantThemeKey(themeKey);
        tenant.setTenantSchemaName(schemaName);
        tenant.setTenantStatus("active");
        tenantRegistryRepository.save(tenant);

        if (contactMobile != null && !contactMobile.isBlank()) {
            seedHospitalAdmin(schemaName, tenantPublicId, contactName, contactMobile, contactEmail);
        }

        return tenant;
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
            String facilityType
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
            provisionTenant(tenantPublicId, hospitalName, "default", contactName, contactMobile, contactEmail);
            
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
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
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
                ready_to_look_patients BOOLEAN DEFAULT true
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
                medicine_id VARCHAR(24) PRIMARY KEY,
                prescription_public_id VARCHAR(24) NOT NULL,
                medicine_name VARCHAR(160),
                dosage VARCHAR(60),
                frequency VARCHAR(60),
                duration VARCHAR(60),
                FOREIGN KEY (prescription_public_id) REFERENCES %s.prescription(prescription_public_id)
            );
            
            CREATE TABLE IF NOT EXISTS %s.medical_history (
                history_public_id VARCHAR(24) PRIMARY KEY,
                patient_public_id VARCHAR(24) NOT NULL,
                tenant_public_id VARCHAR(24) NOT NULL,
                condition_name VARCHAR(160),
                diagnosis_date DATE,
                notes TEXT,
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
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """;

        jdbcTemplate.execute(tenantSchemaDdl.replace("%s", schemaName));
    }

    private static final String GENERIC_ADMIN_MOBILE = "9000000003";

    private void seedHospitalAdmin(String schemaName, String tenantPublicId, String contactName, String contactMobile, String contactEmail) {
        // Seed the real contact admin (if a different mobile is provided)
        boolean contactIsGeneric = GENERIC_ADMIN_MOBILE.equals(contactMobile);
        if (!contactIsGeneric) {
            Integer existingContact = jdbcTemplate.queryForObject(
                    "SELECT COUNT(*) FROM " + schemaName + ".admin_user WHERE mobile_number = ?",
                    Integer.class, contactMobile);
            if (existingContact == null || existingContact == 0) {
                jdbcTemplate.update(
                        "INSERT INTO " + schemaName + ".admin_user (admin_public_id, tenant_public_id, mobile_number, email, name, full_name, active) VALUES (?, ?, ?, ?, ?, ?, ?)",
                        nextAdminPublicId(), tenantPublicId, contactMobile, contactEmail, contactName, contactName, true
                );
            }
        }

        // Always seed the generic admin (9000000003) for every hospital
        Integer existingGeneric = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM " + schemaName + ".admin_user WHERE mobile_number = ?",
                Integer.class, GENERIC_ADMIN_MOBILE);
        if (existingGeneric == null || existingGeneric == 0) {
            jdbcTemplate.update(
                    "INSERT INTO " + schemaName + ".admin_user (admin_public_id, tenant_public_id, mobile_number, email, name, full_name, active) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    nextAdminPublicId(), tenantPublicId, GENERIC_ADMIN_MOBILE, null, "Generic Admin", "Generic Admin", true
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
