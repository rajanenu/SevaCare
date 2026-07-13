-- Dedupe for the POSTs that must never run twice: a booking or a counter sale
-- retried on a flaky mobile network is a double booking or a double dispense,
-- and the ledger would faithfully record both. The client sends a stable
-- Idempotency-Key per attempt; the first request stores its response here and
-- every retry gets that response back instead of a second execution.
CREATE TABLE IF NOT EXISTS public.idempotency_key (
    tenant_public_id VARCHAR(32) NOT NULL,
    idem_key VARCHAR(80) NOT NULL,
    -- Which operation the key was spent on: a key reused across different
    -- endpoints is a client bug and is refused, not replayed.
    endpoint VARCHAR(80) NOT NULL,
    -- NULL only while the first request is still executing (same transaction);
    -- committed rows always carry the response their retries should see.
    response_json TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (tenant_public_id, idem_key)
);

CREATE INDEX IF NOT EXISTS idx_idempotency_created ON public.idempotency_key (created_at);
