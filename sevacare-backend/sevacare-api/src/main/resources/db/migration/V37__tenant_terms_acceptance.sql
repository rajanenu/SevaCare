-- Terms of Service acceptance, recorded per tenant.
--
-- A hospital or a medical store must be able to answer "what did we agree to, and
-- when?" years later — an inspector or an auditor may well ask. So consent is a
-- row, not a checkbox that lives only in a form: the version accepted, the moment
-- it was accepted, and who accepted it.
--
-- NULL terms_version means this tenant has never accepted anything, which is true
-- of every tenant onboarded before this migration. They are asked once, in the app.

ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS terms_version     VARCHAR(16);
ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP;
ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS terms_accepted_by VARCHAR(160);
