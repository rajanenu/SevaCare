-- V11: Add optional profile fields to patient table (both tenant schemas)
ALTER TABLE tenant_t_1001.patient ADD COLUMN IF NOT EXISTS email VARCHAR(120);
ALTER TABLE tenant_t_1001.patient ADD COLUMN IF NOT EXISTS gender VARCHAR(10);
ALTER TABLE tenant_t_1001.patient ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE tenant_t_1001.patient ADD COLUMN IF NOT EXISTS address VARCHAR(500);

ALTER TABLE tenant_t_1002.patient ADD COLUMN IF NOT EXISTS email VARCHAR(120);
ALTER TABLE tenant_t_1002.patient ADD COLUMN IF NOT EXISTS gender VARCHAR(10);
ALTER TABLE tenant_t_1002.patient ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE tenant_t_1002.patient ADD COLUMN IF NOT EXISTS address VARCHAR(500);
