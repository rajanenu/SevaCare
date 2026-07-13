-- User-chosen login passcode, replacing the plaintext user_otp_override.
-- A row means this mobile number set its own 4-digit passcode and the platform
-- default ('0000') no longer works for it; no row means the default still applies.
-- Keyed by mobile number so one passcode covers a person across roles and tenants.
-- The hash is BCrypt — never store the code itself. failed_attempts / locked_until
-- implement the brute-force lockout (a 4-digit space is only 10,000 codes, so the
-- lockout is the actual security, not the hash).
CREATE TABLE IF NOT EXISTS public.user_passcode (
    mobile_number   VARCHAR(24)  PRIMARY KEY,
    passcode_hash   VARCHAR(100) NOT NULL,
    failed_attempts INT          NOT NULL DEFAULT 0,
    locked_until    TIMESTAMP,
    note            VARCHAR(160),
    updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      VARCHAR(64)
);
