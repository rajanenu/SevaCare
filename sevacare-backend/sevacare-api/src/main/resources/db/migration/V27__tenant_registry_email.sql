-- =============================================================
-- V27: Hospital-level support/contact email, editable by the
-- Hospital Admin from their profile. Backfilled best-effort from
-- each tenant's first ADMIN user (seeded from the onboarding
-- contact email) — wrapped per-tenant so one bad row never aborts
-- the rest.
-- =============================================================

ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS email VARCHAR(160);

DO $$
DECLARE
    tenant_row RECORD;
    backfilled_email VARCHAR(160);
BEGIN
    FOR tenant_row IN
        SELECT tenant_public_id, tenant_schema_name FROM public.tenant_registry WHERE email IS NULL
    LOOP
        BEGIN
            EXECUTE format(
                'SELECT email FROM %I.admin_user WHERE user_type = ''ADMIN'' AND email IS NOT NULL ORDER BY admin_public_id LIMIT 1',
                tenant_row.tenant_schema_name
            ) INTO backfilled_email;

            IF backfilled_email IS NOT NULL AND backfilled_email <> '' THEN
                UPDATE public.tenant_registry SET email = backfilled_email WHERE tenant_public_id = tenant_row.tenant_public_id;
            END IF;
        EXCEPTION WHEN OTHERS THEN
            -- Missing admin_user table/column shape for this tenant — skip, don't abort the migration.
            NULL;
        END;
    END LOOP;
END $$;
