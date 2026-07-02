-- V23: Clinic enhancements — consultation_fee on appointment, vitals_summary on appointment
-- Applied per-tenant by TenantAdminSchemaInitializer at startup for any new tenants.
-- For existing tenants (T-1001, T-1013, T-2001) we add the columns here directly.

DO $$
DECLARE
  sch TEXT;
BEGIN
  FOR sch IN
    SELECT schema_name FROM information_schema.schemata
    WHERE schema_name LIKE 'tenant_%'
  LOOP
    EXECUTE format('ALTER TABLE %I.appointment ADD COLUMN IF NOT EXISTS consultation_fee INTEGER DEFAULT 0', sch);
    EXECUTE format('ALTER TABLE %I.appointment ADD COLUMN IF NOT EXISTS vitals_summary VARCHAR(1000)', sch);
  END LOOP;
END $$;
