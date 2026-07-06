-- =============================================================
-- V29: Real backend-backed profile photo storage for Patient, Doctor,
-- and Admin/Staff — same base64-in-column pattern already used for the
-- tenant hero image (tenant_registry.hero_image_base64). Previously
-- photos only ever lived in on-device SharedPreferences, so a doctor's
-- uploaded photo was never visible to a patient viewing them.
-- =============================================================

DO $$
DECLARE
    tenant_schema TEXT;
BEGIN
    FOR tenant_schema IN
        SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'tenant_t_%'
    LOOP
        EXECUTE format('ALTER TABLE %I.patient ADD COLUMN IF NOT EXISTS photo_base64 TEXT', tenant_schema);
        EXECUTE format('ALTER TABLE %I.doctor ADD COLUMN IF NOT EXISTS photo_base64 TEXT', tenant_schema);
        EXECUTE format('ALTER TABLE %I.admin_user ADD COLUMN IF NOT EXISTS photo_base64 TEXT', tenant_schema);
    END LOOP;
END $$;
