-- Session tokens that can actually end.
--
-- auth_refresh_token: one row per live session. The client holds an opaque
-- random token; only its SHA-256 lands here, so a database read never yields a
-- usable credential. Refresh rotates the row (old one gets revoked_at +
-- replaced_by), logout revokes it, and expiry bounds how long a stolen refresh
-- token works. Access JWTs themselves expire in ~60 minutes.
CREATE TABLE IF NOT EXISTS public.auth_refresh_token (
    token_hash        VARCHAR(64) PRIMARY KEY,
    tenant_public_id  VARCHAR(24) NOT NULL,
    role              VARCHAR(24) NOT NULL,
    subject_public_id VARCHAR(24) NOT NULL,
    issued_at         TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at        TIMESTAMP   NOT NULL,
    revoked_at        TIMESTAMP,
    replaced_by       VARCHAR(64)
);

CREATE INDEX IF NOT EXISTS idx_auth_refresh_subject
    ON public.auth_refresh_token (subject_public_id, tenant_public_id);

-- revoked_access_token: real logout for the ~60 minutes an access JWT would
-- otherwise stay valid. Rows are prunable once expires_at passes — the token
-- is dead on its own by then.
CREATE TABLE IF NOT EXISTS public.revoked_access_token (
    jti        VARCHAR(40) PRIMARY KEY,
    expires_at TIMESTAMP   NOT NULL,
    revoked_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
