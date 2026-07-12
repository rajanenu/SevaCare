-- =============================================================
-- V4: Pharmacy — the counter sale and its money.
--
-- Blueprint §7 (billing), §8 (GST). Two invariants live here rather than in the
-- service, for the same reason V3's do:
--
--   1. Money is integer paise, GST is basis points. A CHECK forbids negative
--      money; there is no floating-point rupee anywhere in the schema.
--   2. A sale line names exactly one batch. A strip drawn from two batches is
--      two lines and two ledger rows, because a recall has to answer "which
--      customer got batch X", and only a per-batch line can.
--
-- The sale is the *document*; the stock movement it caused lives in
-- `stock_ledger` (ref_type='SALE', ref_id=sale_public_id). The ledger is the
-- source of truth for stock; this table is the source of truth for money. They
-- are written in one transaction, so a receipt without a stock movement, or the
-- reverse, cannot exist.
-- =============================================================

CREATE SEQUENCE IF NOT EXISTS ${tenantSchema}.sale_public_id_seq;

CREATE TABLE IF NOT EXISTS ${tenantSchema}.sale (
    sale_public_id   VARCHAR(24)  PRIMARY KEY,
    tenant_public_id VARCHAR(24)  NOT NULL,

    -- Human-facing running number on the printed bill. Monotonic; a rolled-back
    -- sale leaves a gap, which is the honest record of an attempt that did not
    -- complete, not something to backfill.
    invoice_no       VARCHAR(32)  NOT NULL,
    location_id      VARCHAR(24)  NOT NULL,

    -- The IST calendar day the sale belongs to, for the day-close report. Kept
    -- separate from sold_at so a sale entered at 00:05 for yesterday's shift can
    -- be dated correctly without timezone arithmetic at report time.
    sale_date        DATE         NOT NULL,
    sold_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    customer_name    VARCHAR(120),
    customer_mobile  VARCHAR(20),
    prescriber_name  VARCHAR(120),

    payment_mode     VARCHAR(16)  NOT NULL DEFAULT 'CASH',

    -- gross = MRP-inclusive amount before discount; total = amount actually paid.
    gross_paise      BIGINT       NOT NULL,
    discount_paise   BIGINT       NOT NULL DEFAULT 0,
    taxable_paise    BIGINT       NOT NULL,
    gst_paise        BIGINT       NOT NULL,
    total_paise      BIGINT       NOT NULL,

    status           VARCHAR(16)  NOT NULL DEFAULT 'COMPLETED',
    actor            VARCHAR(80),
    note             VARCHAR(400),
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_sale_payment CHECK (payment_mode IN ('CASH', 'UPI', 'CARD', 'CREDIT', 'OTHER')),
    CONSTRAINT ck_sale_status  CHECK (status IN ('COMPLETED', 'VOID')),
    CONSTRAINT ck_sale_money   CHECK (gross_paise >= 0 AND discount_paise >= 0
                                      AND taxable_paise >= 0 AND gst_paise >= 0 AND total_paise >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_sale_invoice_no
    ON ${tenantSchema}.sale (invoice_no);
-- The day-close report reads this: every sale for one calendar day.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_sale_date
    ON ${tenantSchema}.sale (sale_date);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.sale_line (
    line_id          BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sale_public_id   VARCHAR(24)  NOT NULL REFERENCES ${tenantSchema}.sale (sale_public_id),

    sku_public_id    VARCHAR(24)  NOT NULL,
    batch_public_id  VARCHAR(24)  NOT NULL,
    -- Snapshotted from the SKU at sale time: what schedule was this when it was
    -- sold, regardless of how the catalog is reclassified later.
    schedule_class   VARCHAR(8),

    qty_base_units   INTEGER      NOT NULL,
    mrp_paise        BIGINT       NOT NULL,     -- per base unit, as printed on the pack

    gross_paise      BIGINT       NOT NULL,     -- mrp * qty
    discount_paise   BIGINT       NOT NULL DEFAULT 0,
    gst_rate_bp      INTEGER      NOT NULL,
    taxable_paise    BIGINT       NOT NULL,     -- gst-exclusive value backed out of the MRP
    gst_paise        BIGINT       NOT NULL,

    CONSTRAINT ck_sale_line_qty   CHECK (qty_base_units > 0),
    CONSTRAINT ck_sale_line_money CHECK (gross_paise >= 0 AND discount_paise >= 0
                                         AND taxable_paise >= 0 AND gst_paise >= 0)
);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_sale_line_sale
    ON ${tenantSchema}.sale_line (sale_public_id);
-- Recall path: "who received batch X". Indexed because that question is asked
-- under time pressure, of the whole history, not just today.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_sale_line_batch
    ON ${tenantSchema}.sale_line (batch_public_id);
