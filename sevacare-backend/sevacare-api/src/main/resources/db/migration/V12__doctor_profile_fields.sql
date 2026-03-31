-- Add doctor profile fields for richer doctor self-profile management
ALTER TABLE tenant_t_1001.doctor
    ADD COLUMN IF NOT EXISTS age INTEGER,
    ADD COLUMN IF NOT EXISTS address VARCHAR(500),
    ADD COLUMN IF NOT EXISTS about_me VARCHAR(1000);

ALTER TABLE tenant_t_1002.doctor
    ADD COLUMN IF NOT EXISTS age INTEGER,
    ADD COLUMN IF NOT EXISTS address VARCHAR(500),
    ADD COLUMN IF NOT EXISTS about_me VARCHAR(1000);
