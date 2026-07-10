-- =============================================================
-- V35: A tenant is a set of modules, not a kind of business.
--
-- The pharmacy has to be sellable to a standalone medical store that has no
-- doctors, no appointments and no patients, and it has to plug into a hospital
-- that already has all three (blueprint §2: "the pharmacy must be fully valuable
-- with zero other SevaCare modules active").
--
-- Two independent switches express that, and there is deliberately no
-- `tenant_kind` column beside them. A derived type is a second source of truth
-- that can disagree with the first, and the disagreement always surfaces as a
-- customer seeing a module they did not buy:
--
--   clinical_enabled = true,  pharmacy_profile_key = NULL       -> hospital (every tenant today)
--   clinical_enabled = false, pharmacy_profile_key = 'MEDICAL_STORE' -> standalone store
--   clinical_enabled = true,  pharmacy_profile_key = 'CLINIC_DISPENSARY' -> both
--
-- The single onboarding question ("what are you?") is a UI concern that maps
-- onto these two columns; it is not stored, because storing an answer that can
-- be recomputed is how the two drift apart.
-- =============================================================

ALTER TABLE public.tenant_registry
    ADD COLUMN IF NOT EXISTS clinical_enabled BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.tenant_registry.clinical_enabled IS
    'Doctors, appointments, prescriptions. False for a standalone pharmacy.';

-- A tenant with every module off is a login that leads to an empty screen. It
-- is never a state anyone wants, and it is cheap to make unrepresentable.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ck_tenant_registry_has_a_module'
    ) THEN
        ALTER TABLE public.tenant_registry
            ADD CONSTRAINT ck_tenant_registry_has_a_module
            CHECK (clinical_enabled OR pharmacy_profile_key IS NOT NULL);
    END IF;
END $$;
