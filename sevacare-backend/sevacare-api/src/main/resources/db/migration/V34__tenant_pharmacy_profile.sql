-- =============================================================
-- V34: Which capability profile is this tenant's pharmacy running?
--
-- Nullable, with no default, and that is the point: pharmacy is OFF for every
-- tenant that existed before it. The V3 tenant migration creates the pharmacy
-- tables in all schemas, but empty tables change nothing. A hospital acquires a
-- pharmacy the day someone chooses what kind of pharmacy it is -- the single
-- onboarding question of blueprint §10.1 -- and not one boot before.
--
-- The value references platform.capability_profile.profile_key. It is not a
-- foreign key: `public` and `platform` are separate planes with separate change
-- cadences, and a profile being retired must not be able to fail a tenant's
-- login. An unknown key resolves to platform defaults and logs.
-- =============================================================

ALTER TABLE public.tenant_registry
    ADD COLUMN IF NOT EXISTS pharmacy_profile_key VARCHAR(32);

COMMENT ON COLUMN public.tenant_registry.pharmacy_profile_key IS
    'platform.capability_profile.profile_key; NULL means this tenant has no pharmacy';
