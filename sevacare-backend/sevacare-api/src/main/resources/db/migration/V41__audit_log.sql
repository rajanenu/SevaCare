-- Who touched which patient's data, and when. Under DPDP — and for basic
-- clinical safety — "who read this record?" must be answerable, and only a log
-- nobody can rewrite answers it. Same discipline as the pharmacy stock ledger:
-- append-only, enforced by the database itself, not by convention.
CREATE TABLE IF NOT EXISTS public.audit_log (
    id BIGSERIAL PRIMARY KEY,
    occurred_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    tenant_public_id VARCHAR(32),
    -- Actor comes from the signed token, never from anything the client typed.
    -- 'PUBLIC' for anonymous PHI writes (the QR booking form).
    actor_role VARCHAR(32) NOT NULL,
    actor_public_id VARCHAR(64),
    -- e.g. PATIENT_READ, PRESCRIPTION_CREATE — subject type + what happened.
    action VARCHAR(64) NOT NULL,
    subject_type VARCHAR(32) NOT NULL,
    -- The specific record touched (public id) when the URL names one; NULL for
    -- list reads. The path column keeps the row self-explanatory either way.
    subject_id VARCHAR(64),
    path VARCHAR(255) NOT NULL,
    client_ip VARCHAR(45)
);

-- "Everything actor X did" and "everyone who touched record Y" are the two
-- questions an investigation asks.
CREATE INDEX IF NOT EXISTS idx_audit_log_tenant_time
    ON public.audit_log (tenant_public_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_subject
    ON public.audit_log (subject_type, subject_id) WHERE subject_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.fn_audit_log_immutable() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is append-only (attempted %).', TG_OP;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_log_immutable ON public.audit_log;
CREATE TRIGGER trg_audit_log_immutable
    BEFORE UPDATE OR DELETE ON public.audit_log
    FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_immutable();
