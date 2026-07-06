package com.sevacare.tenant.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import com.sevacare.tenant.entity.TenantRegistry;

/**
 * Idempotent tenant-schema "shape" repair: adds columns/tables/indexes that the
 * current Doctor/AdminUser/appointment entities and queries expect but that an
 * older createTenantSchema() DDL (or ad-hoc DB surgery) may be missing.
 *
 * Called from two places so schema drift can never survive without a fix:
 *  - {@link TenantAdminSchemaInitializer}, once at boot, for every tenant that
 *    was already active before this process started.
 *  - {@link TenantRegistryService#provisionTenant}, immediately after a
 *    brand-new tenant's raw tables are created — so a hospital onboarded while
 *    the server keeps running (no restart) is correct from the very first
 *    request instead of only after the next restart.
 */
@Component
public class TenantSchemaMaintenanceService {

    private static final Logger log = LoggerFactory.getLogger(TenantSchemaMaintenanceService.class);

    private final JdbcTemplate jdbcTemplate;

    public TenantSchemaMaintenanceService(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public boolean hasSchema(String schemaName) {
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = ?",
                Integer.class,
                schemaName
        );
        return count != null && count > 0;
    }

    public void ensureSchemaShape(TenantRegistry tenant, String schemaName) {
        ensureAdminUserTableShape(schemaName);
        ensureAppointmentTableShape(schemaName);
        ensurePrescriptionTableShape(schemaName);
        ensureNotificationTablesExist(schemaName);
        ensureSlotBlockTableExists(schemaName);
        ensureAppointmentAttachmentTableExists(schemaName);
        ensureDoctorTableShape(tenant, schemaName);
        ensureCoreIndexes(schemaName);
        ensureTokenBookingAndDoctorProfileFields(schemaName);
        ensureBookingSourceField(schemaName);
    }

    private void ensureAdminUserTableShape(String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS mobile_number VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS email VARCHAR(160)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS name VARCHAR(160)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS full_name VARCHAR(160)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".admin_user ADD COLUMN IF NOT EXISTS user_type VARCHAR(16) DEFAULT 'ADMIN'");
        jdbcTemplate.update("UPDATE " + schemaName + ".admin_user SET user_type = 'ADMIN' WHERE user_type IS NULL");
        jdbcTemplate.update(
                "UPDATE " + schemaName + ".admin_user SET full_name = COALESCE(NULLIF(full_name, ''), NULLIF(name, ''), 'Admin User'), " +
                        "name = COALESCE(NULLIF(name, ''), NULLIF(full_name, ''), 'Admin User'), " +
                "active = COALESCE(active, true)"
        );
        log.info("tenant_admin_schema_verified schemaName={}", schemaName);
    }

    private void ensureAppointmentTableShape(String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS appointment_slot VARCHAR(80)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS appointment_status VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS consultation_fee INTEGER DEFAULT 0");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS vitals_summary VARCHAR(1000)");

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
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".prescription ADD COLUMN IF NOT EXISTS appointment_public_id VARCHAR(16)");

        if (hasColumn(schemaName, "prescription", "doctor_public_id")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET doctor_name = COALESCE(doctor_name, doctor_public_id, 'Doctor') WHERE doctor_name IS NULL"
            );
        } else {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".prescription SET doctor_name = COALESCE(doctor_name, 'Doctor') WHERE doctor_name IS NULL"
            );
        }
        // Only backfill issued_on when it is stored as VARCHAR (legacy schema).
        // New schemas define issued_on as DATE NOT NULL DEFAULT CURRENT_DATE — backfill is a no-op
        // and PostgreSQL rejects the VARCHAR COALESCE at parse time for date columns.
        if ("character varying".equals(columnDataType(schemaName, "prescription", "issued_on"))) {
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

    private String columnDataType(String schemaName, String tableName, String columnName) {
        return jdbcTemplate.query(
                "SELECT data_type FROM information_schema.columns WHERE table_schema = ? AND table_name = ? AND column_name = ?",
                rs -> rs.next() ? rs.getString("data_type") : null,
                schemaName, tableName, columnName
        );
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

    private void ensureNotificationTablesExist(String schemaName) {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS %s.leave_request (
                    request_public_id  VARCHAR(32)  PRIMARY KEY,
                    tenant_public_id   VARCHAR(16)  NOT NULL,
                    doctor_public_id   VARCHAR(16)  NOT NULL,
                    doctor_name        VARCHAR(160) NOT NULL DEFAULT '',
                    leave_type         VARCHAR(32)  NOT NULL,
                    from_date          DATE,
                    to_date            DATE,
                    message            TEXT         NOT NULL DEFAULT '',
                    status             VARCHAR(24)  NOT NULL DEFAULT 'PENDING',
                    admin_response     TEXT,
                    submitted_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    responded_at       TIMESTAMP,
                    notified_at        TIMESTAMP,
                    start_time         VARCHAR(5),
                    end_time           VARCHAR(5),
                    requester_type     VARCHAR(16)  NOT NULL DEFAULT 'DOCTOR'
                )""".formatted(schemaName));

        // Hourly leave + staff requesters — added after the table first shipped
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".leave_request ADD COLUMN IF NOT EXISTS start_time VARCHAR(5)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".leave_request ADD COLUMN IF NOT EXISTS end_time VARCHAR(5)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".leave_request ADD COLUMN IF NOT EXISTS requester_type VARCHAR(16) NOT NULL DEFAULT 'DOCTOR'");

        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS %s.app_notification (
                    notification_public_id  VARCHAR(40)  PRIMARY KEY,
                    tenant_public_id        VARCHAR(16)  NOT NULL,
                    recipient_id            VARCHAR(40)  NOT NULL,
                    recipient_type          VARCHAR(16)  NOT NULL,
                    notif_type              VARCHAR(40)  NOT NULL,
                    title                   VARCHAR(200) NOT NULL,
                    body                    TEXT         NOT NULL,
                    reference_id            VARCHAR(40),
                    is_read                 BOOLEAN      NOT NULL DEFAULT FALSE,
                    created_at              TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                )""".formatted(schemaName));

        log.info("notification_tables_ensured schemaName={}", schemaName);
    }

    private void ensureSlotBlockTableExists(String schemaName) {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS %s.slot_block (
                    block_public_id   VARCHAR(40)  PRIMARY KEY,
                    tenant_public_id  VARCHAR(16)  NOT NULL,
                    doctor_public_id  VARCHAR(16)  NOT NULL,
                    block_date        DATE         NOT NULL,
                    start_time        VARCHAR(5)   NOT NULL,
                    end_time          VARCHAR(5)   NOT NULL,
                    reason            VARCHAR(300) NOT NULL DEFAULT '',
                    created_at        TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                )""".formatted(schemaName));
        jdbcTemplate.execute(
                "CREATE INDEX IF NOT EXISTS idx_slot_block_doctor_date ON " + schemaName + ".slot_block (doctor_public_id, block_date)"
        );
        log.info("slot_block_table_ensured schemaName={}", schemaName);
    }

    private void ensureAppointmentAttachmentTableExists(String schemaName) {
        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS %s.appointment_attachment (
                    attachment_public_id  VARCHAR(40)  PRIMARY KEY,
                    tenant_public_id      VARCHAR(16)  NOT NULL,
                    appointment_public_id VARCHAR(16)  NOT NULL,
                    file_name             VARCHAR(200) NOT NULL DEFAULT '',
                    mime_type             VARCHAR(80)  NOT NULL DEFAULT '',
                    data_base64           TEXT         NOT NULL,
                    uploaded_by           VARCHAR(16)  NOT NULL DEFAULT 'PATIENT',
                    created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                )""".formatted(schemaName));
        jdbcTemplate.execute(
                "CREATE INDEX IF NOT EXISTS idx_appointment_attachment_appt ON " + schemaName + ".appointment_attachment (appointment_public_id)"
        );
        log.info("appointment_attachment_table_ensured schemaName={}", schemaName);
    }

    // Some tenants (e.g. tenant_t_2001) were provisioned via an older/ad-hoc path whose
    // doctor table predates most of the columns the current Doctor entity expects
    // (tenant_public_id, availability, fee, active, age, address, about_me,
    // available_from, ready_to_look_patients) — it only ever had a legacy `status`
    // column instead of `active`. Without this, ensureCoreIndexes' indexes on
    // doctor(tenant_public_id/active) fail at startup for those schemas. Idempotent,
    // same pattern as ensureAdminUserTableShape/ensureAppointmentTableShape.
    private void ensureDoctorTableShape(TenantRegistry tenant, String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS availability VARCHAR(160)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS fee VARCHAR(24)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS active BOOLEAN DEFAULT true");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS age INTEGER");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS address VARCHAR(500)");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS about_me TEXT");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS available_from DATE");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS ready_to_look_patients BOOLEAN DEFAULT true");

        jdbcTemplate.update(
                "UPDATE " + schemaName + ".doctor SET tenant_public_id = ? WHERE tenant_public_id IS NULL",
                tenant.getTenantPublicId()
        );
        if (hasColumn(schemaName, "doctor", "status")) {
            jdbcTemplate.update(
                    "UPDATE " + schemaName + ".doctor SET active = COALESCE(active, (status = 'active')) WHERE active IS NULL"
            );
        } else {
            jdbcTemplate.update("UPDATE " + schemaName + ".doctor SET active = true WHERE active IS NULL");
        }
        jdbcTemplate.update("UPDATE " + schemaName + ".doctor SET availability = COALESCE(availability, 'Mon-Sat 9am-5pm') WHERE availability IS NULL");
        jdbcTemplate.update("UPDATE " + schemaName + ".doctor SET fee = COALESCE(fee, '200') WHERE fee IS NULL");
    }

    // V5__create_indexes.sql only targeted the two original tenant schemas that existed
    // at the time. Every tenant onboarded since then gets patient/doctor/appointment/
    // prescription tables with no index beyond the primary key. This runs for every
    // active tenant at startup and is idempotent (IF NOT EXISTS), so it backfills the
    // missing indexes for older tenants and covers all new ones going forward.
    private void ensureCoreIndexes(String schemaName) {
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_patient_tenant ON " + schemaName + ".patient (tenant_public_id)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_patient_mobile ON " + schemaName + ".patient (mobile_number)");

        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_doctor_tenant ON " + schemaName + ".doctor (tenant_public_id)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_doctor_tenant_active ON " + schemaName + ".doctor (tenant_public_id, active)");

        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_appt_patient ON " + schemaName + ".appointment (patient_public_id)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_appt_doctor_status ON " + schemaName + ".appointment (doctor_public_id, appointment_status)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_appt_slot ON " + schemaName + ".appointment (appointment_slot)");

        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_rx_patient ON " + schemaName + ".prescription (patient_public_id)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_rx_doctor ON " + schemaName + ".prescription (doctor_public_id)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_rx_tenant_created ON " + schemaName + ".prescription (tenant_public_id, created_at)");

        // prescription_medicine and medical_history are looked up on every prescription
        // list/detail view and every patient history view respectively, but never had an
        // index beyond the primary key.
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_rx_medicine_rx ON " + schemaName + ".prescription_medicine (prescription_public_id)");
        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_medhistory_patient ON " + schemaName + ".medical_history (tenant_public_id, patient_public_id)");

        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_notif_recipient ON " + schemaName + ".app_notification (tenant_public_id, recipient_id, recipient_type, created_at)");

        jdbcTemplate.execute("CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_leave_tenant_doctor ON " + schemaName + ".leave_request (tenant_public_id, doctor_public_id)");
    }

    // Token-based booking (alongside existing slot booking) and doctor profile fields
    // (years of experience, qualification) used by booking cards and the public doctor
    // directory. Same pattern as ensureCoreIndexes: runs for every active tenant schema,
    // old and new, instead of a Flyway migration hardcoded to specific schemas.
    private void ensureTokenBookingAndDoctorProfileFields(String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS booking_mode VARCHAR(16) NOT NULL DEFAULT 'BOTH'");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS experience_years INTEGER");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".doctor ADD COLUMN IF NOT EXISTS qualification VARCHAR(200)");

        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS booking_type VARCHAR(16) NOT NULL DEFAULT 'SLOT'");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS token_number INTEGER");
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS token_session VARCHAR(16)");

        jdbcTemplate.execute("""
                CREATE TABLE IF NOT EXISTS %s.token_counter (
                    tenant_public_id  VARCHAR(16) NOT NULL,
                    doctor_public_id  VARCHAR(16) NOT NULL,
                    token_date        DATE        NOT NULL,
                    session           VARCHAR(16) NOT NULL,
                    last_token        INTEGER     NOT NULL DEFAULT 0,
                    PRIMARY KEY (tenant_public_id, doctor_public_id, token_date, session)
                )""".formatted(schemaName));

        jdbcTemplate.execute(
                "CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_appt_token ON " + schemaName + ".appointment (doctor_public_id, token_session, token_number)"
        );
        log.info("token_booking_fields_ensured schemaName={}", schemaName);
    }

    // Tracks how each appointment was created (patient app, QR walk-in, or IP-Staff
    // front-desk) so Hospital Admin can see a breakdown of booking channels. IP-Staff
    // bookings were previously only identifiable via a "Booked by IP-Staff" notes marker
    // (still used for per-staff attribution) — this backfills that same set of rows into
    // the new explicit column so historical data isn't lost.
    private void ensureBookingSourceField(String schemaName) {
        jdbcTemplate.execute("ALTER TABLE " + schemaName + ".appointment ADD COLUMN IF NOT EXISTS booking_source VARCHAR(20) NOT NULL DEFAULT 'PATIENT_APP'");
        jdbcTemplate.update(
                "UPDATE " + schemaName + ".appointment SET booking_source = 'IP_STAFF' " +
                "WHERE booking_source = 'PATIENT_APP' AND notes LIKE '%Booked by IP-Staff%'"
        );
        jdbcTemplate.execute(
                "CREATE INDEX IF NOT EXISTS idx_" + schemaName + "_appt_booking_source ON " + schemaName + ".appointment (booking_source)"
        );
    }
}
