CREATE TABLE IF NOT EXISTS public.platform_admin_user (
    platform_admin_public_id VARCHAR(24) PRIMARY KEY,
    full_name VARCHAR(160) NOT NULL,
    mobile_number VARCHAR(24) NOT NULL,
    email VARCHAR(160),
    active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_platform_admin_active
    ON public.platform_admin_user (active);

CREATE UNIQUE INDEX IF NOT EXISTS idx_platform_admin_mobile_number
    ON public.platform_admin_user (mobile_number);

INSERT INTO public.platform_admin_user (platform_admin_public_id, full_name, mobile_number, email, active)
VALUES ('PA-1001', 'SevaCare Platform Admin', '9000000999', 'platform-admin@sevacare.local', true)
ON CONFLICT (platform_admin_public_id) DO NOTHING;