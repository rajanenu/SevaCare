-- =============================================================
-- V10: Pharmacy — the khata (customer credit ledger).
--
-- A CREDIT sale already records who owes (sale.customer_mobile) and how much
-- (sale.total_paise); what was missing is the other half of the ledger — the
-- money coming back. One row here per repayment received at the counter.
-- Outstanding is always DERIVED (credit sales − refunds − payments), never
-- stored, so it can't drift from the documents that justify it.
-- =============================================================

CREATE SEQUENCE IF NOT EXISTS ${tenantSchema}.credit_payment_public_id_seq;

CREATE TABLE IF NOT EXISTS ${tenantSchema}.credit_payment (
    payment_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id  VARCHAR(24) NOT NULL,

    customer_mobile   VARCHAR(20) NOT NULL,
    amount_paise      BIGINT      NOT NULL,
    -- How the repayment arrived. CREDIT is deliberately absent: you cannot
    -- settle credit with credit.
    paid_via          VARCHAR(16) NOT NULL DEFAULT 'CASH',

    note              VARCHAR(300),
    actor             VARCHAR(80),
    paid_at           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_credit_payment_amount CHECK (amount_paise > 0),
    CONSTRAINT ck_credit_payment_via    CHECK (paid_via IN ('CASH', 'UPI', 'CARD'))
);

-- The khata is read per customer: "what has this mobile paid so far".
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_credit_payment_mobile
    ON ${tenantSchema}.credit_payment (customer_mobile);
