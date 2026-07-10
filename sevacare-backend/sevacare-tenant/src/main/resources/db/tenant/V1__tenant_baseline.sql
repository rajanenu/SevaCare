-- =============================================================
-- V1: Tenant schema baseline.
--
-- This is the reconciling baseline for the per-tenant migration runner. It is
-- the merge of the two DDL paths it replaces: TenantRegistryService's
-- createTenantSchema() (fresh-schema DDL) and TenantSchemaMaintenanceService's
-- ensureSchemaShape() (idempotent drift repair, re-run on every boot).
--
-- It is deliberately written to converge ANY starting point:
--   * an empty schema (a hospital onboarded from here on) -> full shape;
--   * a current schema (tenant_t_1013) -> no-op;
--   * an older, drifted schema (tenant_t_2001, provisioned by a long-gone code
--     path) -> the missing tables/columns are added.
--
-- Hence only CREATE TABLE IF NOT EXISTS / ADD COLUMN IF NOT EXISTS /
-- CREATE INDEX IF NOT EXISTS / guarded backfills appear below. We deliberately
-- do NOT drop the legacy columns older schemas carry in addition to this shape
-- (doctor.id, doctor.status, appointment.slot, doctor_schedule.day_of_week, ...).
-- They are unread by any entity and reconciling them means table rewrites; that
-- is a separate, deliberate migration, not a baseline's job.
--
-- After this runs everywhere, drift *below* the baseline is over: V2 onward may
-- be ordinary forward migrations that assume this exact shape.
--
-- Index names are prefixed with the schema name because that is how the
-- ensureCoreIndexes() code that created them on live tenants named them.
-- Changing the convention here would create a second, duplicate index on every
-- existing tenant rather than recognising the one already present.
-- =============================================================

-- ---------------------------------------------------------------
-- Legacy table reconciliation.
--
-- doctor_details, doctor_schedule and doctor_license_metadata exist on the
-- oldest schemas in a different shape: a BIGINT `id` primary key and a column
-- set no current entity maps. CREATE TABLE IF NOT EXISTS would silently skip
-- them and leave those tenants permanently short of the baseline, so the `id`
-- column is used as the marker of a legacy table and it is dropped for the
-- canonical CREATE below to rebuild.
--
-- This is only safe because no code path ever populated them. Assert that
-- rather than assume it: a row here means the premise is wrong, and failing
-- loudly leaves the schema untouched for a human, which is the right outcome.
-- ---------------------------------------------------------------

DO $$
DECLARE
    legacy_table TEXT;
    row_count    BIGINT;
BEGIN
    FOREACH legacy_table IN ARRAY ARRAY['doctor_details', 'doctor_schedule', 'doctor_license_metadata'] LOOP
        IF EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = '${tenantSchema}'
                      AND table_name = legacy_table
                      AND column_name = 'id') THEN
            EXECUTE format('SELECT count(*) FROM %I.%I', '${tenantSchema}', legacy_table) INTO row_count;
            IF row_count > 0 THEN
                RAISE EXCEPTION 'Legacy table %.% holds % row(s); the baseline will not reshape it unattended',
                    '${tenantSchema}', legacy_table, row_count;
            END IF;
            EXECUTE format('DROP TABLE %I.%I', '${tenantSchema}', legacy_table);
        END IF;
    END LOOP;
END $$;

-- ---------------------------------------------------------------
-- Core tables (from createTenantSchema)
-- ---------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ${tenantSchema}.patient (
    patient_public_id     VARCHAR(24) PRIMARY KEY,
    tenant_public_id      VARCHAR(24) NOT NULL,
    full_name             VARCHAR(160) NOT NULL,
    mobile_number         VARCHAR(24) NOT NULL,
    email                 VARCHAR(160),
    age                   INT,
    gender                VARCHAR(24),
    address               TEXT,
    status                VARCHAR(24) DEFAULT 'active',
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deletion_requested_at TIMESTAMP,
    photo_base64          TEXT
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.doctor (
    doctor_public_id       VARCHAR(24) PRIMARY KEY,
    tenant_public_id       VARCHAR(24) NOT NULL,
    full_name              VARCHAR(160) NOT NULL,
    specialty              VARCHAR(120),
    availability           VARCHAR(160),
    fee                    VARCHAR(24),
    mobile_number          VARCHAR(24),
    active                 BOOLEAN DEFAULT true,
    age                    INT,
    address                VARCHAR(160),
    about_me               TEXT,
    available_from         DATE,
    ready_to_look_patients BOOLEAN DEFAULT true,
    booking_mode           VARCHAR(16) NOT NULL DEFAULT 'BOTH',
    experience_years       INT,
    qualification          VARCHAR(200),
    deletion_requested_at  TIMESTAMP,
    photo_base64           TEXT
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.doctor_details (
    doctor_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(24) NOT NULL,
    mobile_number    VARCHAR(24),
    age              INT,
    gender           VARCHAR(24),
    license_number   VARCHAR(80),
    experience_years INT,
    address          VARCHAR(160),
    city             VARCHAR(120),
    state            VARCHAR(120),
    FOREIGN KEY (doctor_public_id) REFERENCES ${tenantSchema}.doctor(doctor_public_id)
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.doctor_schedule (
    schedule_public_id           VARCHAR(24) PRIMARY KEY,
    doctor_public_id             VARCHAR(24) NOT NULL,
    tenant_public_id             VARCHAR(24) NOT NULL,
    appointment_interval_minutes INT,
    lunch_break_start_time       VARCHAR(24),
    lunch_break_end_time         VARCHAR(24),
    max_appointments_per_day     INT,
    working_days                 VARCHAR(200),
    clinic_start_time            VARCHAR(24),
    clinic_end_time              VARCHAR(24),
    FOREIGN KEY (doctor_public_id) REFERENCES ${tenantSchema}.doctor(doctor_public_id)
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.appointment (
    appointment_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id      VARCHAR(24) NOT NULL,
    patient_public_id     VARCHAR(24) NOT NULL,
    doctor_public_id      VARCHAR(24) NOT NULL,
    appointment_date      DATE,
    appointment_slot      VARCHAR(80),
    appointment_status    VARCHAR(24) DEFAULT 'upcoming',
    notes                 TEXT,
    consultation_fee      INTEGER DEFAULT 0,
    vitals_summary        VARCHAR(1000),
    booking_type          VARCHAR(16) NOT NULL DEFAULT 'SLOT',
    token_number          INTEGER,
    token_session         VARCHAR(16),
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_public_id) REFERENCES ${tenantSchema}.patient(patient_public_id),
    FOREIGN KEY (doctor_public_id) REFERENCES ${tenantSchema}.doctor(doctor_public_id)
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.prescription (
    prescription_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id       VARCHAR(24) NOT NULL,
    appointment_public_id  VARCHAR(24),
    patient_public_id      VARCHAR(24) NOT NULL,
    doctor_public_id       VARCHAR(24) NOT NULL,
    doctor_name            VARCHAR(120),
    issued_on              VARCHAR(20),
    prescription_date      DATE,
    notes                  TEXT,
    valid_until            DATE,
    file_url               VARCHAR(500),
    status                 VARCHAR(20) DEFAULT 'active',
    created_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_public_id) REFERENCES ${tenantSchema}.patient(patient_public_id),
    FOREIGN KEY (doctor_public_id) REFERENCES ${tenantSchema}.doctor(doctor_public_id)
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.prescription_medicine (
    id                     BIGSERIAL PRIMARY KEY,
    prescription_public_id VARCHAR(24) NOT NULL,
    medicine_name          VARCHAR(255),
    strength               VARCHAR(100),
    frequency              VARCHAR(255),
    duration               VARCHAR(100),
    instructions           TEXT,
    created_at             TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (prescription_public_id) REFERENCES ${tenantSchema}.prescription(prescription_public_id)
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.medical_history (
    id                BIGSERIAL PRIMARY KEY,
    patient_public_id VARCHAR(24) NOT NULL,
    tenant_public_id  VARCHAR(24) NOT NULL,
    record_type       VARCHAR(50),
    record_value      VARCHAR(255) NOT NULL DEFAULT '',
    notes             TEXT,
    record_date       DATE,
    created_at        TIMESTAMP NOT NULL DEFAULT NOW(),
    FOREIGN KEY (patient_public_id) REFERENCES ${tenantSchema}.patient(patient_public_id)
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.doctor_license_metadata (
    license_public_id VARCHAR(24) PRIMARY KEY,
    doctor_public_id  VARCHAR(24),
    tenant_public_id  VARCHAR(24),
    license_number    VARCHAR(80),
    issuing_authority VARCHAR(160),
    issue_date        DATE,
    expiry_date       DATE
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.admin_user (
    admin_public_id       VARCHAR(24) PRIMARY KEY,
    tenant_public_id      VARCHAR(24) NOT NULL,
    mobile_number         VARCHAR(24),
    email                 VARCHAR(160),
    name                  VARCHAR(160),
    full_name             VARCHAR(160),
    active                BOOLEAN DEFAULT true,
    user_type             VARCHAR(16) DEFAULT 'ADMIN',
    created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deletion_requested_at TIMESTAMP,
    photo_base64          TEXT
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.token_counter (
    tenant_public_id VARCHAR(24) NOT NULL,
    doctor_public_id VARCHAR(24) NOT NULL,
    token_date       DATE        NOT NULL,
    session          VARCHAR(16) NOT NULL,
    last_token       INTEGER     NOT NULL DEFAULT 0,
    PRIMARY KEY (tenant_public_id, doctor_public_id, token_date, session)
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.doctor_review (
    id                    BIGSERIAL PRIMARY KEY,
    appointment_public_id VARCHAR(16) NOT NULL UNIQUE,
    doctor_public_id      VARCHAR(16) NOT NULL,
    patient_public_id     VARCHAR(16) NOT NULL,
    rating                SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment               VARCHAR(1000),
    created_at            TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.leave_request (
    request_public_id VARCHAR(32)  PRIMARY KEY,
    tenant_public_id  VARCHAR(16)  NOT NULL,
    doctor_public_id  VARCHAR(16)  NOT NULL,
    doctor_name       VARCHAR(160) NOT NULL DEFAULT '',
    leave_type        VARCHAR(32)  NOT NULL,
    from_date         DATE,
    to_date           DATE,
    message           TEXT         NOT NULL DEFAULT '',
    status            VARCHAR(24)  NOT NULL DEFAULT 'PENDING',
    admin_response    TEXT,
    submitted_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    responded_at      TIMESTAMP,
    notified_at       TIMESTAMP,
    start_time        VARCHAR(5),
    end_time          VARCHAR(5),
    requester_type    VARCHAR(16)  NOT NULL DEFAULT 'DOCTOR'
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.app_notification (
    notification_public_id VARCHAR(40)  PRIMARY KEY,
    tenant_public_id       VARCHAR(16)  NOT NULL,
    recipient_id           VARCHAR(40)  NOT NULL,
    recipient_type         VARCHAR(16)  NOT NULL,
    notif_type             VARCHAR(40)  NOT NULL,
    title                  VARCHAR(200) NOT NULL,
    body                   TEXT         NOT NULL,
    reference_id           VARCHAR(40),
    is_read                BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at             TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.slot_block (
    block_public_id  VARCHAR(40)  PRIMARY KEY,
    tenant_public_id VARCHAR(16)  NOT NULL,
    doctor_public_id VARCHAR(16)  NOT NULL,
    block_date       DATE         NOT NULL,
    start_time       VARCHAR(5)   NOT NULL,
    end_time         VARCHAR(5)   NOT NULL,
    reason           VARCHAR(300) NOT NULL DEFAULT '',
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.appointment_attachment (
    attachment_public_id  VARCHAR(40)  PRIMARY KEY,
    tenant_public_id      VARCHAR(16)  NOT NULL,
    appointment_public_id VARCHAR(16)  NOT NULL,
    file_name             VARCHAR(200) NOT NULL DEFAULT '',
    mime_type             VARCHAR(80)  NOT NULL DEFAULT '',
    data_base64           TEXT         NOT NULL,
    uploaded_by           VARCHAR(16)  NOT NULL DEFAULT 'PATIENT',
    created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.doctor_availability (
    id               BIGSERIAL PRIMARY KEY,
    doctor_public_id VARCHAR(16) NOT NULL,
    day_scope        VARCHAR(16) NOT NULL,
    session_label    VARCHAR(20) NOT NULL,
    start_time       TIME        NOT NULL,
    end_time         TIME        NOT NULL,
    active           BOOLEAN     NOT NULL DEFAULT true,
    created_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------
-- Columns older schemas may be missing (from ensureSchemaShape)
-- ---------------------------------------------------------------

ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS mobile_number VARCHAR(24);
ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS email         VARCHAR(160);
ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS name          VARCHAR(160);
ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS full_name     VARCHAR(160);
ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS active        BOOLEAN DEFAULT true;
ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS user_type     VARCHAR(16) DEFAULT 'ADMIN';

ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS appointment_slot   VARCHAR(80);
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS appointment_status VARCHAR(24);
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS tenant_public_id   VARCHAR(24);
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS consultation_fee   INTEGER DEFAULT 0;
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS vitals_summary     VARCHAR(1000);
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS booking_type       VARCHAR(16) NOT NULL DEFAULT 'SLOT';
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS token_number       INTEGER;
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS token_session      VARCHAR(16);
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS booking_source     VARCHAR(20) NOT NULL DEFAULT 'PATIENT_APP';
-- Read by backfills, indexes and the Appointment entity; assume nothing about old schemas.
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS appointment_date   DATE;
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS notes              TEXT;
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS created_at         TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS doctor_name           VARCHAR(120);
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS doctor_public_id      VARCHAR(24);
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS issued_on             VARCHAR(20);
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS status                VARCHAR(20) DEFAULT 'active';
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS file_url              VARCHAR(500);
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS valid_until           DATE;
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS updated_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS tenant_public_id      VARCHAR(24);
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS appointment_public_id VARCHAR(16);
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS created_at            TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE ${tenantSchema}.prescription ADD COLUMN IF NOT EXISTS prescription_date     DATE;

-- ---------------------------------------------------------------
-- Column type reconciliation.
--
-- Two columns exist on the oldest schemas with a type the entities do not map.
-- ADD COLUMN IF NOT EXISTS cannot see this, so they are converted explicitly:
--
--   prescription.issued_on  DATE -> VARCHAR(20)
--       Prescription.issuedOn is a String. PostgreSQL will not implicitly cast
--       a varchar bind parameter into a date column, so writing a prescription
--       on such a tenant fails today. This is a live bug, not cosmetic drift.
--   appointment.notes  VARCHAR(300) -> TEXT
--       TEXT is the canonical, wider type; widening never loses a row.
--
-- Both are table rewrites, so unlike the inert legacy *columns* left in place
-- above, they are only attempted when the table is empty. Every schema this
-- applies to has zero rows in them; if that ever stops being true the ALTER is
-- skipped rather than blocking the rewrite of a live table during startup.
-- ---------------------------------------------------------------

DO $$
DECLARE
    current_type TEXT;
BEGIN
    SELECT data_type INTO current_type FROM information_schema.columns
     WHERE table_schema = '${tenantSchema}' AND table_name = 'prescription' AND column_name = 'issued_on';
    IF current_type = 'date'
       AND (SELECT count(*) FROM ${tenantSchema}.prescription) = 0 THEN
        EXECUTE 'ALTER TABLE ${tenantSchema}.prescription ALTER COLUMN issued_on TYPE VARCHAR(20) USING to_char(issued_on, ''YYYY-MM-DD'')';
    END IF;

    SELECT data_type INTO current_type FROM information_schema.columns
     WHERE table_schema = '${tenantSchema}' AND table_name = 'appointment' AND column_name = 'notes';
    IF current_type = 'character varying'
       AND (SELECT count(*) FROM ${tenantSchema}.appointment) = 0 THEN
        EXECUTE 'ALTER TABLE ${tenantSchema}.appointment ALTER COLUMN notes TYPE TEXT';
    END IF;
END $$;

ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS tenant_public_id       VARCHAR(24);
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS availability           VARCHAR(160);
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS fee                    VARCHAR(24);
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS active                 BOOLEAN DEFAULT true;
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS age                    INTEGER;
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS address                VARCHAR(500);
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS about_me               TEXT;
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS available_from         DATE;
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS ready_to_look_patients BOOLEAN DEFAULT true;
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS booking_mode           VARCHAR(16) NOT NULL DEFAULT 'BOTH';
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS experience_years       INTEGER;
ALTER TABLE ${tenantSchema}.doctor ADD COLUMN IF NOT EXISTS qualification          VARCHAR(200);

ALTER TABLE ${tenantSchema}.leave_request ADD COLUMN IF NOT EXISTS start_time     VARCHAR(5);
ALTER TABLE ${tenantSchema}.leave_request ADD COLUMN IF NOT EXISTS end_time       VARCHAR(5);
ALTER TABLE ${tenantSchema}.leave_request ADD COLUMN IF NOT EXISTS requester_type VARCHAR(16) NOT NULL DEFAULT 'DOCTOR';

-- Date-range scoping: NULL dates mean unbounded, so pre-existing rows keep
-- their old behaviour unchanged.
ALTER TABLE ${tenantSchema}.doctor_availability ADD COLUMN IF NOT EXISTS from_date        DATE;
ALTER TABLE ${tenantSchema}.doctor_availability ADD COLUMN IF NOT EXISTS to_date          DATE;
ALTER TABLE ${tenantSchema}.doctor_availability ADD COLUMN IF NOT EXISTS include_saturday BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE ${tenantSchema}.doctor_availability ADD COLUMN IF NOT EXISTS include_sunday   BOOLEAN NOT NULL DEFAULT true;

-- ---------------------------------------------------------------
-- Backfills. Guarded where an older schema may lack the source column.
-- ---------------------------------------------------------------

UPDATE ${tenantSchema}.admin_user SET user_type = 'ADMIN' WHERE user_type IS NULL;
UPDATE ${tenantSchema}.admin_user SET
    full_name = COALESCE(NULLIF(full_name, ''), NULLIF(name, ''), 'Admin User'),
    name      = COALESCE(NULLIF(name, ''), NULLIF(full_name, ''), 'Admin User'),
    active    = COALESCE(active, true);

-- Legacy `slot`/`status` columns feed the current appointment_slot/appointment_status.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = '${tenantSchema}' AND table_name = 'appointment' AND column_name = 'slot') THEN
        EXECUTE 'UPDATE ${tenantSchema}.appointment SET appointment_slot = COALESCE(appointment_slot, slot) WHERE appointment_slot IS NULL';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = '${tenantSchema}' AND table_name = 'appointment' AND column_name = 'status') THEN
        EXECUTE 'UPDATE ${tenantSchema}.appointment SET appointment_status = COALESCE(appointment_status, status, ''upcoming'') WHERE appointment_status IS NULL';
    END IF;
END $$;

UPDATE ${tenantSchema}.appointment SET appointment_slot   = 'General OPD' WHERE appointment_slot IS NULL;
UPDATE ${tenantSchema}.appointment SET appointment_status = 'upcoming'    WHERE appointment_status IS NULL;

-- IP-Staff bookings used to be identifiable only by a notes marker (still used
-- for per-staff attribution). Backfill that set into the explicit column so
-- historical channel analytics aren't missing them.
UPDATE ${tenantSchema}.appointment SET booking_source = 'IP_STAFF'
 WHERE booking_source = 'PATIENT_APP' AND notes LIKE '%Booked by IP-Staff%';

UPDATE ${tenantSchema}.prescription SET doctor_name = COALESCE(doctor_name, doctor_public_id, 'Doctor') WHERE doctor_name IS NULL;
UPDATE ${tenantSchema}.prescription SET status = 'active' WHERE status IS NULL;
UPDATE ${tenantSchema}.prescription SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;

-- issued_on is VARCHAR on the schemas that predate it being a DATE. Only the
-- VARCHAR form can take this backfill — PostgreSQL rejects the VARCHAR COALESCE
-- against a date column at parse time, so the whole block must be guarded.
DO $$
DECLARE
    issued_on_type TEXT;
    has_rx_date    BOOLEAN;
BEGIN
    SELECT data_type INTO issued_on_type FROM information_schema.columns
     WHERE table_schema = '${tenantSchema}' AND table_name = 'prescription' AND column_name = 'issued_on';

    IF issued_on_type IS DISTINCT FROM 'character varying' THEN
        RETURN;
    END IF;

    SELECT EXISTS (SELECT 1 FROM information_schema.columns
                   WHERE table_schema = '${tenantSchema}' AND table_name = 'prescription' AND column_name = 'prescription_date')
      INTO has_rx_date;

    IF has_rx_date THEN
        EXECUTE 'UPDATE ${tenantSchema}.prescription SET issued_on = COALESCE(CAST(prescription_date AS VARCHAR), CAST(created_at AS VARCHAR), CURRENT_DATE::VARCHAR) WHERE issued_on IS NULL';
    ELSE
        EXECUTE 'UPDATE ${tenantSchema}.prescription SET issued_on = COALESCE(CAST(created_at AS VARCHAR), CURRENT_DATE::VARCHAR) WHERE issued_on IS NULL';
    END IF;
END $$;

-- Older schemas carry a legacy `status` text column instead of `active`.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = '${tenantSchema}' AND table_name = 'doctor' AND column_name = 'status') THEN
        EXECUTE 'UPDATE ${tenantSchema}.doctor SET active = (status = ''active'') WHERE active IS NULL';
    END IF;
END $$;

UPDATE ${tenantSchema}.doctor SET tenant_public_id = '${tenantPublicId}' WHERE tenant_public_id IS NULL;
UPDATE ${tenantSchema}.doctor SET active       = true               WHERE active IS NULL;
UPDATE ${tenantSchema}.doctor SET availability = 'Mon-Sat 9am-5pm'  WHERE availability IS NULL;
UPDATE ${tenantSchema}.doctor SET fee          = '200'              WHERE fee IS NULL;

-- Every doctor without an availability rule gets the two windows that used to be
-- hardcoded for everyone, so no existing doctor's bookable hours change here.
INSERT INTO ${tenantSchema}.doctor_availability (doctor_public_id, day_scope, session_label, start_time, end_time)
SELECT d.doctor_public_id, 'EVERYDAY', s.session_label, s.start_time, s.end_time
  FROM ${tenantSchema}.doctor d
 CROSS JOIN (VALUES ('Morning', TIME '09:00', TIME '14:00'),
                    ('Evening', TIME '17:00', TIME '21:00')) AS s(session_label, start_time, end_time)
 WHERE NOT EXISTS (SELECT 1 FROM ${tenantSchema}.doctor_availability a
                    WHERE a.doctor_public_id = d.doctor_public_id);

-- ---------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_patient_tenant       ON ${tenantSchema}.patient (tenant_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_patient_mobile       ON ${tenantSchema}.patient (mobile_number);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_doctor_tenant        ON ${tenantSchema}.doctor (tenant_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_doctor_tenant_active ON ${tenantSchema}.doctor (tenant_public_id, active);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_appt_patient         ON ${tenantSchema}.appointment (patient_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_appt_doctor_status   ON ${tenantSchema}.appointment (doctor_public_id, appointment_status);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_appt_slot            ON ${tenantSchema}.appointment (appointment_slot);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_appt_token           ON ${tenantSchema}.appointment (doctor_public_id, token_session, token_number);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_appt_booking_source  ON ${tenantSchema}.appointment (booking_source);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_rx_patient           ON ${tenantSchema}.prescription (patient_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_rx_doctor            ON ${tenantSchema}.prescription (doctor_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_rx_tenant_created    ON ${tenantSchema}.prescription (tenant_public_id, created_at);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_rx_medicine_rx       ON ${tenantSchema}.prescription_medicine (prescription_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_medhistory_patient   ON ${tenantSchema}.medical_history (tenant_public_id, patient_public_id);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_notif_recipient      ON ${tenantSchema}.app_notification (tenant_public_id, recipient_id, recipient_type, created_at);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_leave_tenant_doctor  ON ${tenantSchema}.leave_request (tenant_public_id, doctor_public_id);

CREATE INDEX IF NOT EXISTS idx_slot_block_doctor_date               ON ${tenantSchema}.slot_block (doctor_public_id, block_date);
CREATE INDEX IF NOT EXISTS idx_appointment_attachment_appt          ON ${tenantSchema}.appointment_attachment (appointment_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_doctor_availability_doctor ON ${tenantSchema}.doctor_availability (doctor_public_id);
