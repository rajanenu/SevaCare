-- V30: Add city + pin_code to public.tenant_registry so the schema matches the
-- TenantRegistry entity (@Column city NOT NULL, pin_code NOT NULL). These columns
-- were previously added out-of-band on existing environments (schema drift); this
-- migration versions them so a fresh database boots cleanly. Idempotent.
ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS city VARCHAR(120) NOT NULL DEFAULT '';
ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS pin_code VARCHAR(10) NOT NULL DEFAULT '';
