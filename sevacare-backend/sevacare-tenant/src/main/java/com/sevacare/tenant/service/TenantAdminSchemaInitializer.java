package com.sevacare.tenant.service;

import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.sevacare.tenant.entity.TenantRegistry;
import com.sevacare.tenant.repository.TenantRegistryRepository;

@Component
public class TenantAdminSchemaInitializer implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(TenantAdminSchemaInitializer.class);

    private final TenantRegistryRepository tenantRegistryRepository;
    private final TenantRegistryService tenantRegistryService;
    private final JdbcTemplate jdbcTemplate;

    public TenantAdminSchemaInitializer(
            TenantRegistryRepository tenantRegistryRepository,
            TenantRegistryService tenantRegistryService,
            JdbcTemplate jdbcTemplate
    ) {
        this.tenantRegistryRepository = tenantRegistryRepository;
        this.tenantRegistryService = tenantRegistryService;
        this.jdbcTemplate = jdbcTemplate;
    }

    @Override
    public void run(ApplicationArguments args) {
        List<TenantRegistry> tenants = tenantRegistryRepository.findByTenantStatus("active");
        for (TenantRegistry tenant : tenants) {
            String schemaName = tenant.getTenantSchemaName();
            if (!hasSchema(schemaName)) {
                log.warn("tenant_schema_missing_skip schemaName={} tenantPublicId={}", schemaName, tenant.getTenantPublicId());
                continue;
            }
            ensureAdminUserTableShape(tenant, schemaName);
            ensureAppointmentTableShape(schemaName);
            ensurePrescriptionTableShape(schemaName);
        }
    }

    private void ensureAdminUserTableShape(TenantRegistry tenant, String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS mobile_number VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS email VARCHAR(160)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS name VARCHAR(160)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS full_name VARCHAR(160)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
        jdbcTemplate.update(
                "UPDATE " + schemaName + ".admin_user SET full_name = COALESCE(NULLIF(full_name, ''), NULLIF(name, ''), 'Admin User'), " +
                        "name = COALESCE(NULLIF(name, ''), NULLIF(full_name, ''), 'Admin User'), " +
                "active = COALESCE(active, true), " +
                "mobile_number = COALESCE(NULLIF(mobile_number, ''), '9000000003')"
        );
        seedDefaultAdminIfMissing(tenant, schemaName);
        log.info("tenant_admin_schema_verified schemaName={}", schemaName);
    }

    private void seedDefaultAdminIfMissing(TenantRegistry tenant, String schemaName) {
        Integer adminCount = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM " + schemaName + ".admin_user", Integer.class);
        if (adminCount != null && adminCount > 0) {
            return;
        }

        String adminPublicId = tenantRegistryService.nextAdminPublicId();
        String fullName = tenant.getTenantName() + " Admin";
        jdbcTemplate.update(
                "INSERT INTO " + schemaName + ".admin_user (admin_public_id, tenant_public_id, mobile_number, email, name, full_name, active) VALUES (?, ?, ?, ?, ?, ?, ?)",
                adminPublicId,
                tenant.getTenantPublicId(),
                "9000000003",
                "admin@sevacare.local",
                fullName,
                fullName,
                true
        );
        log.info("tenant_admin_seeded tenantPublicId={} adminPublicId={}", tenant.getTenantPublicId(), adminPublicId);
    }

    private void ensureAppointmentTableShape(String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS appointment_slot VARCHAR(80)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS appointment_status VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(24)");

        if (hasColumn(schemaName, "appointment", "slot")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".appointment SET appointment_slot = COALESCE(appointment_slot, slot) WHERE appointment_slot IS NULL"
            );
        }
        jdbcTemplate.update(
                "UPDATE " + schemaName + ".appointment SET appointment_slot = COALESCE(appointment_slot, 'General OPD') WHERE appointment_slot IS NULL"
        );

        if (hasColumn(schemaName, "appointment", "status")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".appointment SET appointment_status = COALESCE(appointment_status, status, 'upcoming') WHERE appointment_status IS NULL"
            );
        } else {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".appointment SET appointment_status = COALESCE(appointment_status, 'upcoming') WHERE appointment_status IS NULL"
            );
        }
    }

    private void ensurePrescriptionTableShape(String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS doctor_name VARCHAR(120)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS doctor_public_id VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS issued_on VARCHAR(20)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active'");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS file_url VARCHAR(500)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS valid_until DATE");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(24)");

        if (hasColumn(schemaName, "prescription", "doctor_public_id")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET doctor_name = COALESCE(doctor_name, doctor_public_id, 'Doctor') WHERE doctor_name IS NULL"
            );
        } else {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET doctor_name = COALESCE(doctor_name, 'Doctor') WHERE doctor_name IS NULL"
            );
        }
        if (hasColumn(schemaName, "prescription", "prescription_date") && hasColumn(schemaName, "prescription", "created_at")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET issued_on = COALESCE(issued_on, CAST(prescription_date AS VARCHAR), CAST(created_at AS VARCHAR), CURRENT_DATE::VARCHAR) WHERE issued_on IS NULL"
            );
        } else if (hasColumn(schemaName, "prescription", "prescription_date")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET issued_on = COALESCE(issued_on, CAST(prescription_date AS VARCHAR), CURRENT_DATE::VARCHAR) WHERE issued_on IS NULL"
            );
        } else if (hasColumn(schemaName, "prescription", "created_at")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET issued_on = COALESCE(issued_on, CAST(created_at AS VARCHAR), CURRENT_DATE::VARCHAR) WHERE issued_on IS NULL"
            );
        } else {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET issued_on = COALESCE(issued_on, CURRENT_DATE::VARCHAR) WHERE issued_on IS NULL"
            );
        }
        jdbcTemplate.update(
                "UPDATE " + schemaName + ".prescription SET status = COALESCE(status, 'active') WHERE status IS NULL"
        );
        if (hasColumn(schemaName, "prescription", "created_at")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET updated_at = COALESCE(updated_at, created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL"
            );
        } else {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET updated_at = COALESCE(updated_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL"
            );
        }
    }

    private boolean hasColumn(String schemaName, String tableName, String columnName) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = ? AND table_name = ? AND column_name = ?",
                Integer.class,
                schemaName,
                tableName,
                columnName
        );
        return count != null && count > 0;
    }

    private boolean hasSchema(String schemaName) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = ?",
                Integer.class,
                schemaName
        );
        return count != null && count > 0;
    }
}