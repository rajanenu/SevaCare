-- Per-user OTP override. When a row exists for a mobile number that OTP is
-- required at login; otherwise the platform default ('0000') applies. Keyed by
-- mobile number so one row covers a person across roles and tenants.
CREATE TABLE IF NOT EXISTS public.user_otp_override (
    mobile_number VARCHAR(24) PRIMARY KEY,
    otp           VARCHAR(6)  NOT NULL,
    note          VARCHAR(160),
    updated_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
