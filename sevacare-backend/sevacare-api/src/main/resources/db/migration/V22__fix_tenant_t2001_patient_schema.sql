-- V22: Fix tenant_t_2001.patient table - add missing tenant_public_id column
-- This tenant was created with an older schema that lacked tenant_public_id.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'tenant_t_2001') THEN

    ALTER TABLE tenant_t_2001.patient ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(24);
    UPDATE tenant_t_2001.patient SET tenant_public_id = 'T-2001' WHERE tenant_public_id IS NULL;

    -- Seed a demo patient for T-2001 if none exist
    INSERT INTO tenant_t_2001.patient (patient_public_id, tenant_public_id, full_name, mobile_number, status)
    VALUES ('P-2001', 'T-2001', 'Demo Patient', '9000000001', 'active')
    ON CONFLICT (patient_public_id) DO NOTHING;

  END IF;
END $$;
