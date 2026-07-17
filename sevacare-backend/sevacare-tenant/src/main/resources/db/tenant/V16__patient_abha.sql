-- ABDM readiness: a patient may link their Ayushman Bharat Health Account.
-- abha_number is the 14-digit id (stored with its xx-xxxx-xxxx-xxxx hyphens),
-- abha_address the PHR handle (name@abdm). Both optional — nothing about
-- registration changes for a patient who has neither.
ALTER TABLE ${tenantSchema}.patient ADD COLUMN IF NOT EXISTS abha_number VARCHAR(17);
ALTER TABLE ${tenantSchema}.patient ADD COLUMN IF NOT EXISTS abha_address VARCHAR(64);
