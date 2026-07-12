-- =============================================================
-- V5: Pharmacy Phase 1 completion — suppliers, the GRN document,
--     customer returns, and the day-close.
--
-- Blueprint §7.3 (GRN), §7.4 (returns), §11.2 (owner Money view), §19 Phase 1.
--
-- The GRN and the return are *documents*: the stock they moved lives in
-- `stock_ledger` (ref_type='GRN'/'RETURN', ref_id=the document id), exactly as a
-- sale does. The document is the source of truth for money and provenance; the
-- ledger is the source of truth for stock; they commit in one transaction.
-- =============================================================

CREATE SEQUENCE IF NOT EXISTS ${tenantSchema}.supplier_public_id_seq;
CREATE SEQUENCE IF NOT EXISTS ${tenantSchema}.grn_public_id_seq;
CREATE SEQUENCE IF NOT EXISTS ${tenantSchema}.customer_return_public_id_seq;

-- ---------------------------------------------------------------
-- Suppliers. `return_window_days` is the heart of the expiry-return money loop
-- (blueprint §8.4): near-expiry stock must go back before this window closes or
-- the loss is the store's. Captured at onboarding of the supplier, used by the
-- near-expiry queue to show a deadline, not just a date.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ${tenantSchema}.supplier (
    supplier_public_id VARCHAR(24)  PRIMARY KEY,
    tenant_public_id   VARCHAR(24)  NOT NULL,
    supplier_name      VARCHAR(160) NOT NULL,
    mobile_number      VARCHAR(20),
    gstin              VARCHAR(20),
    city               VARCHAR(80),
    return_window_days INTEGER      NOT NULL DEFAULT 90,
    note               VARCHAR(400),
    active             BOOLEAN      NOT NULL DEFAULT true,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_supplier_window CHECK (return_window_days >= 0)
);

-- The same distributor typed twice is the #1 master-data mess in small stores.
CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_supplier_name
    ON ${tenantSchema}.supplier (upper(supplier_name));

-- ---------------------------------------------------------------
-- Goods receipt. One document per delivery/invoice; each line creates (or finds)
-- a batch and appends one GRN ledger row. A GRN may exist with no supplier and
-- no invoice number — the owner phoned the distributor and a carton arrived —
-- because refusing to record reality is how stock goes wrong (Law 1).
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ${tenantSchema}.goods_receipt (
    grn_public_id       VARCHAR(24)  PRIMARY KEY,
    tenant_public_id    VARCHAR(24)  NOT NULL,
    supplier_public_id  VARCHAR(24)  REFERENCES ${tenantSchema}.supplier (supplier_public_id),
    supplier_invoice_no VARCHAR(60),
    invoice_date        DATE,

    line_count          INTEGER      NOT NULL,
    total_qty_base      BIGINT       NOT NULL,
    -- What was paid for the delivery (invoice value, integer paise). Free scheme
    -- quantities carry no cost; they lower the effective unit cost instead.
    total_cost_paise    BIGINT       NOT NULL DEFAULT 0,

    status              VARCHAR(16)  NOT NULL DEFAULT 'POSTED',
    actor               VARCHAR(80),
    note                VARCHAR(400),
    received_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_grn_status CHECK (status IN ('POSTED')),
    CONSTRAINT ck_grn_money  CHECK (total_cost_paise >= 0)
);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_grn_received
    ON ${tenantSchema}.goods_receipt (received_at DESC);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.grn_line (
    line_id              BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    grn_public_id        VARCHAR(24) NOT NULL REFERENCES ${tenantSchema}.goods_receipt (grn_public_id),

    sku_public_id        VARCHAR(24) NOT NULL,
    batch_public_id      VARCHAR(24) NOT NULL,
    batch_no             VARCHAR(40) NOT NULL,
    expiry_date          DATE,

    qty_base_units       INTEGER     NOT NULL,
    -- The Indian "10+1" scheme: free units received on top of the billed ones.
    -- They enter stock like any unit but cost nothing — which is why true margin
    -- (blueprint innovation #10) can only be computed from the GRN line.
    free_qty_base_units  INTEGER     NOT NULL DEFAULT 0,

    mrp_paise            BIGINT      NOT NULL,
    -- Invoice price per billed base unit, as printed. The batch's effective unit
    -- cost (paid ÷ all units incl. free) is derived at post time.
    purchase_price_paise BIGINT,

    CONSTRAINT ck_grn_line_qty  CHECK (qty_base_units > 0 AND free_qty_base_units >= 0),
    CONSTRAINT ck_grn_line_mrp  CHECK (mrp_paise >= 0),
    CONSTRAINT ck_grn_line_cost CHECK (purchase_price_paise IS NULL OR purchase_price_paise >= 0)
);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_grn_line_grn
    ON ${tenantSchema}.grn_line (grn_public_id);
-- Supplier price history is a query, not a table: sku × supplier × date → price
-- falls out of grn_line ⨝ goods_receipt. This index makes that query real.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_grn_line_sku
    ON ${tenantSchema}.grn_line (sku_public_id);

-- ---------------------------------------------------------------
-- Customer returns. Always against a bill (the sale is the provenance a drug
-- inspector asks for), line-by-line, with a per-line disposition: RESTOCK puts
-- it back on the shelf (ledger RETURN_IN at the counter), QUARANTINE parks it
-- where it cannot be resold (ledger RETURN_IN at QUARANTINE) — opened strips,
-- cold-chain doubts, anything the pharmacist wouldn't re-sell to their own
-- family.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ${tenantSchema}.customer_return (
    return_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(24) NOT NULL,
    sale_public_id   VARCHAR(24) NOT NULL REFERENCES ${tenantSchema}.sale (sale_public_id),

    refund_paise     BIGINT      NOT NULL,
    refund_mode      VARCHAR(16) NOT NULL DEFAULT 'CASH',
    reason           VARCHAR(400),
    actor            VARCHAR(80),
    returned_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- The IST day the refund left the drawer — day-close subtracts it from
    -- expected cash, so the drawer count still reconciles on a day with returns.
    return_date      DATE        NOT NULL,

    CONSTRAINT ck_return_refund CHECK (refund_paise >= 0),
    CONSTRAINT ck_return_mode   CHECK (refund_mode IN ('CASH', 'UPI', 'CARD', 'CREDIT', 'OTHER'))
);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_return_sale
    ON ${tenantSchema}.customer_return (sale_public_id);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_return_date
    ON ${tenantSchema}.customer_return (return_date);

CREATE TABLE IF NOT EXISTS ${tenantSchema}.customer_return_line (
    line_id          BIGINT      GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    return_public_id VARCHAR(24) NOT NULL REFERENCES ${tenantSchema}.customer_return (return_public_id),

    sku_public_id    VARCHAR(24) NOT NULL,
    batch_public_id  VARCHAR(24) NOT NULL,
    qty_base_units   INTEGER     NOT NULL,
    amount_paise     BIGINT      NOT NULL,
    disposition      VARCHAR(16) NOT NULL,

    CONSTRAINT ck_return_line_qty    CHECK (qty_base_units > 0),
    CONSTRAINT ck_return_line_amount CHECK (amount_paise >= 0),
    CONSTRAINT ck_return_line_disp   CHECK (disposition IN ('RESTOCK', 'QUARANTINE'))
);

CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_return_line_return
    ON ${tenantSchema}.customer_return_line (return_public_id);

-- ---------------------------------------------------------------
-- Day-close. One row per IST calendar day: what the system expected in the cash
-- drawer versus what was counted, and the honest difference. Closing is a
-- statement ("I counted"), not a lock on reality — a sale rung at 23:59 after
-- the close still exists, and tomorrow's variance carries the story.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ${tenantSchema}.day_close (
    close_date           DATE        PRIMARY KEY,
    tenant_public_id     VARCHAR(24) NOT NULL,

    sale_count           INTEGER     NOT NULL,
    total_paise          BIGINT      NOT NULL,
    -- CASH takings minus CASH refunds: what should physically be in the drawer.
    expected_cash_paise  BIGINT      NOT NULL,
    counted_cash_paise   BIGINT      NOT NULL,
    variance_paise       BIGINT      NOT NULL,

    note                 VARCHAR(400),
    closed_by            VARCHAR(80),
    closed_at            TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
