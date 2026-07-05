-- V24: Hospital hero image — shown as the glassmorphism login-screen background
-- once a hospital is selected. Uploaded by the platform admin, served publicly
-- via the tenant directory. Stored as base64 TEXT (matches the
-- appointment-attachment base64-in-DB pattern).

ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS hero_image_base64 TEXT;
ALTER TABLE public.tenant_registry ADD COLUMN IF NOT EXISTS hero_image_content_type VARCHAR(64);
