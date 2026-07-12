-- The tenant registry is read far more often than it is written, on two hot paths:
--
--   1. The public directory. "Search Hospitals" and "Search Pharmacies" now ask the
--      database for one module's tenants rather than fetching every tenant and sieving
--      them in memory, so the filter is a WHERE clause that deserves an index.
--   2. The outbox dispatcher, which lists active tenants every few seconds, forever.
--
-- Partial indexes, because both paths only ever ask about *active* tenants: the index
-- stays as small as the answer, and a deactivated tenant costs nothing to carry.

-- Every active tenant (the dispatcher's per-tick list, and the unfiltered directory).
CREATE INDEX IF NOT EXISTS idx_tenant_registry_active
    ON public.tenant_registry (tenant_public_id)
    WHERE tenant_status = 'active';

-- "Search Hospitals" — active tenants that have a clinical side.
CREATE INDEX IF NOT EXISTS idx_tenant_registry_active_clinical
    ON public.tenant_registry (tenant_public_id)
    WHERE tenant_status = 'active' AND clinical_enabled = true;

-- "Search Pharmacies" — active tenants that dispense. A NULL pharmacy_profile_key is
-- precisely "no pharmacy" (see TenantModuleService), so NOT NULL is the whole test.
CREATE INDEX IF NOT EXISTS idx_tenant_registry_active_pharmacy
    ON public.tenant_registry (tenant_public_id)
    WHERE tenant_status = 'active' AND pharmacy_profile_key IS NOT NULL;
