DO $$
DECLARE v_schema_name TEXT;
BEGIN
  FOR v_schema_name IN
    SELECT s.schema_name
    FROM information_schema.schemata s
    WHERE s.schema_name LIKE 'tenant_t_%'
  LOOP
    EXECUTE format('ALTER TABLE %I.doctor ADD COLUMN IF NOT EXISTS mobile_number VARCHAR(24);', v_schema_name);
  END LOOP;
END $$;
