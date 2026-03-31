CREATE SEQUENCE IF NOT EXISTS public.onboarding_document_public_id_seq START WITH 1001;

CREATE TABLE IF NOT EXISTS public.tenant_onboarding_document (
    document_public_id VARCHAR(24) PRIMARY KEY,
    request_public_id VARCHAR(24) NOT NULL,
    original_file_name VARCHAR(255) NOT NULL,
    stored_file_name VARCHAR(255) NOT NULL UNIQUE,
    content_type VARCHAR(160),
    file_size BIGINT NOT NULL,
    storage_path VARCHAR(600) NOT NULL,
    uploaded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_onboarding_document_request
        FOREIGN KEY (request_public_id)
        REFERENCES public.tenant_onboarding_request(request_public_id)
        ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_onboarding_document_request
    ON public.tenant_onboarding_document (request_public_id);
