-- =============================================================
-- V28: Self-service account deletion for Patient, Doctor, Admin/Staff,
-- and Platform Admin. Deletion never removes rows or FK-linked history —
-- it only disables login (existing status/active flags), and this column
-- just records when the disable happened for support/audit purposes.
-- =============================================================

DO $$
DECLARE
    tenant_schema TEXT;
BEGIN
    FOR tenant_schema IN
        SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'tenant_t_%'
    LOOP
        EXECUTE format('ALTER TABLE %I.patient ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMP', tenant_schema);
        EXECUTE format('ALTER TABLE %I.doctor ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMP', tenant_schema);
        EXECUTE format('ALTER TABLE %I.admin_user ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMP', tenant_schema);
    END LOOP;
END $$;

ALTER TABLE public.platform_admin_user ADD COLUMN IF NOT EXISTS deletion_requested_at TIMESTAMP;
