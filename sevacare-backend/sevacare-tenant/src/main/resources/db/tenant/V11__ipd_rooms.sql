-- =============================================================
-- V11: In-patient (IPD) rooms — the simplest shape that answers
-- "which patient is in which room".
--
-- One patient per room: no per-bed identity, no future reservations. A room is
-- AVAILABLE or OCCUPIED; an admission ties a patient to a room until they are
-- discharged. Admit sets the room OCCUPIED, discharge frees it. Partial unique
-- indexes make a double-booked live room, or a patient admitted twice at once,
-- impossible at the database — the front desk cannot get it wrong.
--
-- blood_group joins the patient record here too: one field the desk fills once
-- and every screen can read.
--
-- Forward migration (assumes the V1 baseline shape). Idempotent so the boot
-- sweep can re-run it against any tenant schema safely.
-- =============================================================

ALTER TABLE ${tenantSchema}.patient
    ADD COLUMN IF NOT EXISTS blood_group VARCHAR(8);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.room (
    room_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_public_id VARCHAR(24) NOT NULL,
    label            VARCHAR(60) NOT NULL,
    room_type        VARCHAR(40),
    status           VARCHAR(16) NOT NULL DEFAULT 'AVAILABLE',
    created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- "Room 101" is one physical room — a label is unique per tenant.
CREATE UNIQUE INDEX IF NOT EXISTS room_label_unique
    ON ${tenantSchema}.room (tenant_public_id, LOWER(label));

CREATE TABLE IF NOT EXISTS ${tenantSchema}.admission (
    admission_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_public_id  VARCHAR(24) NOT NULL,
    patient_public_id VARCHAR(24) NOT NULL,
    room_id           BIGINT NOT NULL REFERENCES ${tenantSchema}.room (room_id),
    status            VARCHAR(16) NOT NULL DEFAULT 'ADMITTED',
    admitted_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    discharged_at     TIMESTAMP,
    admitted_by       VARCHAR(120),
    notes             TEXT
);

-- A room holds at most one live admission; a patient occupies at most one room.
CREATE UNIQUE INDEX IF NOT EXISTS admission_active_room_unique
    ON ${tenantSchema}.admission (room_id) WHERE status = 'ADMITTED';
CREATE UNIQUE INDEX IF NOT EXISTS admission_active_patient_unique
    ON ${tenantSchema}.admission (patient_public_id) WHERE status = 'ADMITTED';

CREATE INDEX IF NOT EXISTS admission_tenant_status_idx
    ON ${tenantSchema}.admission (tenant_public_id, status);
