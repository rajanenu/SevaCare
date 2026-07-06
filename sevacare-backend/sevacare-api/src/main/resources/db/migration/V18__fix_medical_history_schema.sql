-- V18: Align medical_history table schema for the runtime-onboarded tenants
-- tenant_t_1013 (old schema: history_public_id, condition_name, diagnosis_date)
-- tenant_t_2001 (missing tenant_public_id).
-- Both are guarded by schema-existence checks (V20/V22 pattern) so a fresh
-- database — where neither tenant has been onboarded — migrates cleanly.

-- ── Fix tenant_t_1013 ──────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'tenant_t_1013') THEN

    -- Drop the old VARCHAR primary key and related constraint
    ALTER TABLE tenant_t_1013.medical_history DROP CONSTRAINT IF EXISTS medical_history_pkey;
    ALTER TABLE tenant_t_1013.medical_history DROP COLUMN IF EXISTS history_public_id;

    -- Add serial id as the new primary key
    ALTER TABLE tenant_t_1013.medical_history ADD COLUMN IF NOT EXISTS id BIGSERIAL PRIMARY KEY;

    -- Rename old columns to match entity (only if the old column is still present)
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'tenant_t_1013' AND table_name = 'medical_history'
                 AND column_name = 'condition_name') THEN
      ALTER TABLE tenant_t_1013.medical_history RENAME COLUMN condition_name TO record_value;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns
               WHERE table_schema = 'tenant_t_1013' AND table_name = 'medical_history'
                 AND column_name = 'diagnosis_date') THEN
      ALTER TABLE tenant_t_1013.medical_history RENAME COLUMN diagnosis_date TO record_date;
    END IF;

    -- Add missing columns
    ALTER TABLE tenant_t_1013.medical_history ADD COLUMN IF NOT EXISTS record_type VARCHAR(50);
    ALTER TABLE tenant_t_1013.medical_history ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NOT NULL DEFAULT NOW();

    -- Add performance index
    CREATE INDEX IF NOT EXISTS idx_medical_history_tenant_patient_t1013
        ON tenant_t_1013.medical_history(tenant_public_id, patient_public_id);

  END IF;
END $$;

-- ── Fix tenant_t_2001 ──────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'tenant_t_2001') THEN

    -- Add missing tenant_public_id column
    ALTER TABLE tenant_t_2001.medical_history ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(24);
    UPDATE tenant_t_2001.medical_history SET tenant_public_id = 'T-2001' WHERE tenant_public_id IS NULL;
    ALTER TABLE tenant_t_2001.medical_history ALTER COLUMN tenant_public_id SET NOT NULL;

    -- Add performance index
    CREATE INDEX IF NOT EXISTS idx_medical_history_tenant_patient_t2001
        ON tenant_t_2001.medical_history(tenant_public_id, patient_public_id);

  END IF;
END $$;
