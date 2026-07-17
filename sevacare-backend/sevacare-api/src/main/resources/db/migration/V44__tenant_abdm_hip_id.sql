-- ABDM Scan & Share routes a patient's profile to a facility by its Health
-- Facility Registry id (the "HIP id"). This column maps that id back to the
-- tenant, so the one public webhook can serve every facility we host.
ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS abdm_hip_id VARCHAR(64);

CREATE UNIQUE INDEX IF NOT EXISTS uq_tenant_registry_abdm_hip_id
    ON public.tenant_registry (abdm_hip_id) WHERE abdm_hip_id IS NOT NULL;
