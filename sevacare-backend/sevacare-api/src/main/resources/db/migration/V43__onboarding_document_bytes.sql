-- Onboarding documents used to be written to the container's local disk, which on
-- Cloud Run is per-instance and wiped on every restart — an uploaded licence was
-- unreadable from any other instance and gone after a deploy. The bytes now live in
-- the row itself (they are small one-time uploads, and this way they ride along with
-- the DB's own backups at no extra cost). storage_path stays only for legacy rows
-- written by older local-dev builds.
ALTER TABLE public.tenant_onboarding_document ADD COLUMN IF NOT EXISTS file_bytes BYTEA;
ALTER TABLE public.tenant_onboarding_document ALTER COLUMN storage_path DROP NOT NULL;
