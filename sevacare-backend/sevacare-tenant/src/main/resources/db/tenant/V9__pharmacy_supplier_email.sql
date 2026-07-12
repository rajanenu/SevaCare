-- =============================================================
-- V9: An email address for a supplier — the bulk refill request
-- ("send these low-stock items to my distributor") needs somewhere to send
-- to besides WhatsApp.
-- =============================================================

ALTER TABLE ${tenantSchema}.supplier
    ADD COLUMN IF NOT EXISTS email VARCHAR(160);
