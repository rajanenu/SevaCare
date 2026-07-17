-- Patient refill cycles, computed from the store's own sales cadence: a customer
-- who has bought the same SKU on two or more days establishes a rhythm, and one
-- row here is one "they are about to run out" cycle. The scan that fills this
-- table is idempotent — the partial unique index below allows exactly one OPEN
-- cycle per (customer, sku), so re-running the scan can never double-remind.
--
-- Status walk: DUE (scan found it) → NOTIFIED (WhatsApp queued) → FULFILLED
-- (they bought again) or DISMISSED (counter closed it by hand).
CREATE TABLE IF NOT EXISTS ${tenantSchema}.refill_reminder (
    id               BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tenant_public_id VARCHAR(24)  NOT NULL,
    customer_mobile  VARCHAR(20)  NOT NULL,
    customer_name    VARCHAR(120),
    sku_public_id    VARCHAR(24)  NOT NULL,
    brand_name       VARCHAR(200) NOT NULL,

    -- The purchase rhythm this cycle was derived from.
    last_sale_date   DATE         NOT NULL,
    cadence_days     INTEGER      NOT NULL,
    due_date         DATE         NOT NULL,

    status           VARCHAR(16)  NOT NULL DEFAULT 'DUE',
    notified_at      TIMESTAMP,
    resolved_at      TIMESTAMP,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_refill_status  CHECK (status IN ('DUE', 'NOTIFIED', 'FULFILLED', 'DISMISSED')),
    CONSTRAINT ck_refill_cadence CHECK (cadence_days > 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_refill_open
    ON ${tenantSchema}.refill_reminder (customer_mobile, sku_public_id)
    WHERE status IN ('DUE', 'NOTIFIED');

-- The counter worklist reads open cycles by due date.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_refill_due
    ON ${tenantSchema}.refill_reminder (status, due_date);
