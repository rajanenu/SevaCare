-- Profile photos move to the deduplicated public.media store (see public V45).
-- Each row keeps a content-addressed reference (the SHA-256 of its image) here;
-- the actual bytes live once in public.media. photo_base64 stays as a read
-- fallback until MediaBackfillService has migrated every row.
ALTER TABLE ${tenantSchema}.patient    ADD COLUMN IF NOT EXISTS photo_media_sha VARCHAR(64);
ALTER TABLE ${tenantSchema}.doctor     ADD COLUMN IF NOT EXISTS photo_media_sha VARCHAR(64);
ALTER TABLE ${tenantSchema}.admin_user ADD COLUMN IF NOT EXISTS photo_media_sha VARCHAR(64);
