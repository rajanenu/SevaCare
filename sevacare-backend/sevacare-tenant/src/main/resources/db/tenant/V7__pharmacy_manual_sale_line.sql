-- =============================================================
-- V7: Pharmacy — a sale line for something that isn't in the catalog.
--
-- A counter sells more than medicines: a courier bag, a delivery charge, a
-- casual item nobody bothered to SKU. `sale_line` required a real
-- sku_public_id/batch_public_id, so there was no way to bill one of these
-- without inventing a fake catalog entry for it.
--
-- The CHECK below keeps the two shapes mutually exclusive rather than
-- relying on the service layer alone: a catalog line always names exactly
-- one SKU and one batch; a manual line always carries a label and neither.
-- =============================================================

ALTER TABLE ${tenantSchema}.sale_line
    ALTER COLUMN sku_public_id DROP NOT NULL,
    ALTER COLUMN batch_public_id DROP NOT NULL,
    ADD COLUMN IF NOT EXISTS manual_label VARCHAR(200);

ALTER TABLE ${tenantSchema}.sale_line
    DROP CONSTRAINT IF EXISTS ck_sale_line_shape;

ALTER TABLE ${tenantSchema}.sale_line
    ADD CONSTRAINT ck_sale_line_shape CHECK (
        (sku_public_id IS NOT NULL AND batch_public_id IS NOT NULL AND manual_label IS NULL)
        OR
        (sku_public_id IS NULL AND batch_public_id IS NULL AND manual_label IS NOT NULL)
    );
