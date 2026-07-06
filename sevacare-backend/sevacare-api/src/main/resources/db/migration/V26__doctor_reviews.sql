-- =============================================================
-- V26: Doctor ratings & reviews — one 5-star review per completed
-- appointment, feeding the average rating shown on Explore Doctors.
-- =============================================================

DO $$
DECLARE
    tenant_schema TEXT;
BEGIN
    FOR tenant_schema IN
        SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'tenant_t_%'
    LOOP
        EXECUTE format('
            CREATE TABLE IF NOT EXISTS %I.doctor_review (
                id BIGSERIAL PRIMARY KEY,
                appointment_public_id VARCHAR(16) NOT NULL UNIQUE,
                doctor_public_id VARCHAR(16) NOT NULL,
                patient_public_id VARCHAR(16) NOT NULL,
                rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
                comment VARCHAR(1000),
                created_at TIMESTAMP NOT NULL DEFAULT now()
            )', tenant_schema);
    END LOOP;
END $$;
