-- Zero-cost media store: image/document bytes live here as deduplicated BYTEA,
-- content-addressed by their SHA-256. Identical uploads (e.g. the same stock
-- avatar assigned to many staff) collapse to one row. Served from
-- /api/v1/public/media/{sha256} with an immutable Cache-Control + ETag, so each
-- image is fetched once, ever, then a 304 or a client cache hit. This keeps
-- media inside Cloud SQL — no object store to pay for — while getting the bytes
-- out of the base64 TEXT columns and out of JSON payloads.
--
-- The previous home for these bytes (patient/doctor/admin_user.photo_base64 and
-- tenant_registry.hero_image_base64) is kept as a read-fallback until the
-- backfill (MediaBackfillService) has moved every row across; new writes go
-- straight to media and set the *_media_sha reference, nulling the base64.

CREATE TABLE IF NOT EXISTS public.media (
    sha256        VARCHAR(64)  PRIMARY KEY,
    content_type  VARCHAR(100) NOT NULL,
    byte_size     INTEGER      NOT NULL,
    bytes         BYTEA        NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Hero image reference (bytes move to public.media). base64 kept for fallback.
ALTER TABLE public.tenant_registry
    ADD COLUMN IF NOT EXISTS hero_image_media_sha VARCHAR(64);
