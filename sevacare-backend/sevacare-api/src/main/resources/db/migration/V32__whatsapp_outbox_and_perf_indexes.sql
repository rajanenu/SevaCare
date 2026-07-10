-- =============================================================
-- V32: WhatsApp delivery outbox + hot-path indexes.
--
-- The outbox is the single durable queue for every outbound WhatsApp
-- message (prescriptions, booking confirmations, follow-up reminders).
-- Rows are written inside the same transaction as the business event, so
-- a message can never be queued for a booking that rolled back. A
-- background drainer picks up rows whose scheduled_at has passed, which
-- is what lets a follow-up reminder be enqueued weeks ahead of delivery.
-- =============================================================

CREATE TABLE IF NOT EXISTS public.whatsapp_outbox (
    id               BIGSERIAL PRIMARY KEY,
    tenant_public_id VARCHAR(16)  NOT NULL,
    to_mobile        VARCHAR(24)  NOT NULL,
    message_type     VARCHAR(32)  NOT NULL,
    reference_id     VARCHAR(64)  NOT NULL,
    body             TEXT         NOT NULL,
    wa_link          TEXT,
    status           VARCHAR(16)  NOT NULL DEFAULT 'PENDING',
    attempts         SMALLINT     NOT NULL DEFAULT 0,
    last_error       VARCHAR(500),
    scheduled_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    sent_at          TIMESTAMP
);

-- One message per (tenant, type, business object): re-running a consult
-- upload or a reminder sweep can never double-send.
CREATE UNIQUE INDEX IF NOT EXISTS uq_whatsapp_outbox_ref
    ON public.whatsapp_outbox(tenant_public_id, message_type, reference_id);

-- Drainer lookup: pending rows whose delivery time has arrived.
CREATE INDEX IF NOT EXISTS idx_whatsapp_outbox_due
    ON public.whatsapp_outbox(status, scheduled_at);

-- ── Hot-path indexes ────────────────────────────────────────────────────
-- The doctor inbox sorts pending-first per (tenant, doctor); the patient
-- lookup by mobile powers QR/chatbot find-or-create.
CREATE INDEX IF NOT EXISTS idx_appointment_request_tenant_doctor
    ON public.appointment_request(tenant_public_id, doctor_public_id, request_status);
CREATE INDEX IF NOT EXISTS idx_appointment_request_mobile
    ON public.appointment_request(tenant_public_id, patient_mobile);

-- Every tenant schema (including ones created after V5, which only covered
-- t_1001/t_1002) gets the indexes the queue, consult and history screens hit
-- on every poll.
DO $$
DECLARE
    tenant_schema TEXT;
    spec          TEXT[];
    specs         TEXT[][] := ARRAY[
        ['appointment',          'appt_doctor_slot',    'doctor_public_id, appointment_slot'],
        ['appointment',          'appt_tenant_status',  'tenant_public_id, appointment_status'],
        ['appointment',          'appt_tenant_patient', 'tenant_public_id, patient_public_id'],
        ['prescription',         'rx_tenant_patient',   'tenant_public_id, patient_public_id'],
        ['prescription_medicine','rx_med_rx',           'prescription_public_id'],
        ['patient',              'patient_mobile_idx',  'tenant_public_id, mobile_number'],
        ['leave_request',        'leave_doctor_dates',  'doctor_public_id, from_date, to_date']
    ];
BEGIN
    FOR tenant_schema IN
        SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'tenant_t_%'
    LOOP
        FOREACH spec SLICE 1 IN ARRAY specs
        LOOP
            -- Schemas provisioned by different migrations don't all carry the
            -- same tables; skip the ones this schema doesn't have rather than
            -- aborting the whole migration.
            CONTINUE WHEN to_regclass(format('%I.%I', tenant_schema, spec[1])) IS NULL;
            EXECUTE format('CREATE INDEX IF NOT EXISTS %I ON %I.%I (%s)',
                'idx_' || tenant_schema || '_' || spec[2], tenant_schema, spec[1], spec[3]);
        END LOOP;
    END LOOP;
END $$;
