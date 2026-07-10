-- =============================================================
-- V3: Pharmacy — Catalog, Inventory (the stock ledger), and the policy store.
--
-- Blueprint §5.2 (tenant plane), §6 (the stock ledger), §10 (capability knobs).
--
-- Three decisions in this file are load-bearing and are enforced here rather
-- than in Java, because a rule that lives only in a service is a rule until
-- someone writes a second service:
--
--   1. `stock_ledger` is append-only. UPDATE and DELETE raise. Mistakes are
--      corrected by compensating rows (`correction_of`), never by editing
--      history -- which is also the only lawful way to keep a controlled-drug
--      register.
--   2. `batch_balance` is a derived cache, never the source of truth. Writing
--      it outside the ledger-append path raises. The append path announces
--      itself with a transaction-scoped GUC; nothing else can.
--   3. Quantities are in BASE UNITS (tablets, ml) everywhere in the ledger.
--      Pack structure is display context, held in `sku_pack`. This is what
--      makes "4 tablets out of a strip of 10" -- the most common operation at
--      an Indian counter -- ordinary arithmetic rather than fractional stock.
--
-- Index names carry the schema name to match the convention V1/V2 established.
-- =============================================================

-- ---------------------------------------------------------------
-- Public-id sequences.
--
-- These are tenant-local, unlike `public.patient_public_id_seq`. A SKU id has
-- no meaning outside the pharmacy that stocks it, the tables are per-schema,
-- and a store owner reading "SKU-0001" should see their first SKU, not their
-- 41,000th. Nothing joins these across tenants, so nothing needs them global.
-- ---------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS ${tenantSchema}.sku_public_id_seq;
CREATE SEQUENCE IF NOT EXISTS ${tenantSchema}.batch_public_id_seq;

-- =============================================================
-- CATALOG  --  "What can this pharmacy sell?"
-- =============================================================

-- The tenant catalog is sovereign: `drug_public_id` links to
-- platform.drug_master but is NULLABLE and carries NO foreign key. A pharmacy
-- sells surgical items, ayurvedic preparations and local brands the master has
-- never heard of, and the master is a different plane with a different backup
-- and change cadence. Platform linkage enriches (substitution, interactions);
-- it never gates a sale.
CREATE TABLE IF NOT EXISTS ${tenantSchema}.medicine_sku (
    sku_public_id    VARCHAR(24)  PRIMARY KEY,
    tenant_public_id VARCHAR(24)  NOT NULL,

    drug_public_id   VARCHAR(24),

    brand_name       VARCHAR(200) NOT NULL,
    manufacturer     VARCHAR(200),
    dosage_form      VARCHAR(40),
    strength         VARCHAR(80),

    -- TABLET | CAPSULE | ML | GM | UNIT. The atom the ledger counts.
    base_unit        VARCHAR(16)  NOT NULL DEFAULT 'UNIT',

    -- Copied from the drug master at creation, then owned by the tenant: a
    -- pharmacist who knows this box is 12% GST must be able to say so without
    -- waiting for us to fix the master.
    schedule_class   VARCHAR(8),
    hsn_code         VARCHAR(12),
    gst_rate_bp      INTEGER      NOT NULL DEFAULT 0,

    rack_location    VARCHAR(40),
    reorder_level    INTEGER,
    reorder_qty      INTEGER,

    active           BOOLEAN      NOT NULL DEFAULT true,
    created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version          BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT ck_sku_gst_rate     CHECK (gst_rate_bp BETWEEN 0 AND 10000),
    CONSTRAINT ck_sku_reorder      CHECK (reorder_level IS NULL OR reorder_level >= 0),
    CONSTRAINT ck_sku_reorder_qty  CHECK (reorder_qty IS NULL OR reorder_qty > 0)
);

-- Counter search types three letters and expects an answer before the fourth.
-- `text_pattern_ops` because the query is a prefix LIKE: the default opclass
-- compares by the database collation and Postgres will not use it for LIKE
-- unless the collation happens to be C. (pg_trgm for infix/fuzzy search arrives
-- with the resolution engine in Phase 2; prefix is what the counter types.)
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_sku_brand
    ON ${tenantSchema}.medicine_sku (lower(brand_name) text_pattern_ops);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_sku_rack
    ON ${tenantSchema}.medicine_sku (rack_location) WHERE rack_location IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_sku_drug
    ON ${tenantSchema}.medicine_sku (drug_public_id) WHERE drug_public_id IS NOT NULL;

-- Learned vocabulary: the doctor's scrawl, the customer's mispronunciation, the
-- barcode on the box. Every confirmed resolution writes one of these, so the
-- tenant's own shorthand becomes an asset it accumulates.
CREATE TABLE IF NOT EXISTS ${tenantSchema}.sku_alias (
    alias_id      BIGSERIAL    PRIMARY KEY,
    sku_public_id VARCHAR(24)  NOT NULL REFERENCES ${tenantSchema}.medicine_sku (sku_public_id) ON DELETE CASCADE,

    alias         VARCHAR(200) NOT NULL,
    -- MANUAL (a human typed it) | LEARNED (a confirmed resolution) |
    -- BARCODE | IMPORT (came in with a Marg/Excel migration)
    alias_kind    VARCHAR(16)  NOT NULL DEFAULT 'MANUAL',
    hit_count     INTEGER      NOT NULL DEFAULT 0,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_alias_kind CHECK (alias_kind IN ('MANUAL', 'LEARNED', 'BARCODE', 'IMPORT'))
);

-- Case-insensitive, because "PCM 650" and "pcm 650" are the same scrawl.
CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_sku_alias
    ON ${tenantSchema}.sku_alias (sku_public_id, lower(alias));
-- Serves both the scanner (exact barcode `=`) and the counter (prefix LIKE).
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_sku_alias_lookup
    ON ${tenantSchema}.sku_alias (lower(alias) text_pattern_ops);

-- box = 10 strips, strip = 10 tablets, tablet = 1. `units_in_pack` is always in
-- BASE units, not in the level below, so a lookup never has to walk a chain and
-- a mis-entered middle level cannot silently rescale the levels above it.
CREATE TABLE IF NOT EXISTS ${tenantSchema}.sku_pack (
    pack_id       BIGSERIAL   PRIMARY KEY,
    sku_public_id VARCHAR(24) NOT NULL REFERENCES ${tenantSchema}.medicine_sku (sku_public_id) ON DELETE CASCADE,

    pack_name     VARCHAR(40) NOT NULL,
    units_in_pack INTEGER     NOT NULL,
    -- Can a customer buy this level? A loose tablet usually yes; a box maybe.
    sellable      BOOLEAN     NOT NULL DEFAULT true,
    is_base       BOOLEAN     NOT NULL DEFAULT false,
    sort_order    SMALLINT    NOT NULL DEFAULT 0,

    CONSTRAINT ck_pack_units    CHECK (units_in_pack > 0),
    CONSTRAINT ck_pack_base_one CHECK (NOT is_base OR units_in_pack = 1)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_sku_pack_name
    ON ${tenantSchema}.sku_pack (sku_public_id, lower(pack_name));
-- Exactly one base level per SKU, and it is the unit the ledger counts.
CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_sku_pack_base
    ON ${tenantSchema}.sku_pack (sku_public_id) WHERE is_base;

-- =============================================================
-- INVENTORY  --  "Where is every unit, and how did it get there?"
-- =============================================================

-- TRANSIT and QUARANTINE are virtual but real: stock that "left but never
-- arrived", and stock pulled from sale pending a return claim, both have to
-- live somewhere that still sums. Systems that cannot represent them lose the
-- goods and the argument.
CREATE TABLE IF NOT EXISTS ${tenantSchema}.stock_location (
    location_id      VARCHAR(32) PRIMARY KEY,
    tenant_public_id VARCHAR(24) NOT NULL,
    display_name     VARCHAR(80) NOT NULL,
    location_kind    VARCHAR(16) NOT NULL,
    is_default       BOOLEAN     NOT NULL DEFAULT false,
    active           BOOLEAN     NOT NULL DEFAULT true,
    created_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_location_kind CHECK (location_kind IN
        ('COUNTER', 'STORE', 'COLD', 'QUARANTINE', 'TRANSIT', 'WARD'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_stock_location_default
    ON ${tenantSchema}.stock_location (tenant_public_id) WHERE is_default;

-- Every store has a counter and a back room on day one. Seeded so that a fresh
-- pharmacy can receive its first GRN without first visiting a settings page.
INSERT INTO ${tenantSchema}.stock_location
    (location_id, tenant_public_id, display_name, location_kind, is_default)
VALUES
    ('COUNTER',    '${tenantPublicId}', 'Counter',    'COUNTER',    true),
    ('STORE',      '${tenantPublicId}', 'Store room', 'STORE',      false),
    ('QUARANTINE', '${tenantPublicId}', 'Quarantine', 'QUARANTINE', false)
ON CONFLICT (location_id) DO NOTHING;

-- A batch is the unit of expiry, of MRP, and of recall. `expiry_date` is
-- nullable because surgical items and consumables genuinely have none, and a
-- forced fake expiry would poison the near-expiry queue for everyone.
CREATE TABLE IF NOT EXISTS ${tenantSchema}.batch (
    batch_public_id      VARCHAR(24)  PRIMARY KEY,
    tenant_public_id     VARCHAR(24)  NOT NULL,
    sku_public_id        VARCHAR(24)  NOT NULL REFERENCES ${tenantSchema}.medicine_sku (sku_public_id),

    batch_no             VARCHAR(40)  NOT NULL,
    -- The LAST USABLE DAY, not the first unusable one. A pack marked "07/2026"
    -- may lawfully be dispensed through 31 Jul 2026, so a GRN stores the last
    -- day of the printed month and every check reads `expiry_date >= today`.
    expiry_date          DATE,

    -- Money is integer paise. A floating-point rupee is a bug waiting for an
    -- auditor. MRP is per BASE unit: a strip of 10 at MRP 50.00 stores 500.
    mrp_paise            BIGINT       NOT NULL,
    purchase_price_paise BIGINT,

    supplier_public_id   VARCHAR(24),

    -- ACTIVE -> NEAR_EXPIRY -> EXPIRED -> DISPOSED, orthogonally QUARANTINED /
    -- RECALLED. Derived by scheduler and re-checked lazily at dispense: a
    -- scheduler race has already bitten this codebase once.
    batch_status         VARCHAR(16)  NOT NULL DEFAULT 'ACTIVE',

    created_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at           TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version              BIGINT       NOT NULL DEFAULT 0,

    CONSTRAINT ck_batch_status CHECK (batch_status IN
        ('ACTIVE', 'NEAR_EXPIRY', 'EXPIRED', 'QUARANTINED', 'RECALLED', 'DISPOSED')),
    CONSTRAINT ck_batch_mrp        CHECK (mrp_paise >= 0),
    CONSTRAINT ck_batch_cost       CHECK (purchase_price_paise IS NULL OR purchase_price_paise >= 0)
);

-- The same batch number from two manufacturers is two batches; the same batch
-- number for the same SKU is one, however many times the truck arrives.
CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_batch_no
    ON ${tenantSchema}.batch (sku_public_id, upper(batch_no));
-- FEFO reads this: oldest usable expiry first, for one SKU.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_batch_fefo
    ON ${tenantSchema}.batch (sku_public_id, expiry_date)
    WHERE batch_status IN ('ACTIVE', 'NEAR_EXPIRY');
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_batch_expiry
    ON ${tenantSchema}.batch (expiry_date) WHERE expiry_date IS NOT NULL;

-- ---------------------------------------------------------------
-- The stock ledger. The most consequential table in the pharmacy.
--
-- Note the absence of any sign CHECK tying `reason` to the direction of
-- `qty_delta`. It is tempting (GRN must be positive, SALE must be negative) and
-- it is wrong: a correction of a GRN is a negative GRN row, and a correction of
-- a sale is a positive one. The reversal chain keeps the reason of the fact it
-- reverses, because "why did this stock move" is answered by the original
-- business event, not by the bookkeeping that fixed it.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ${tenantSchema}.stock_ledger (
    ledger_id        BIGSERIAL    PRIMARY KEY,
    tenant_public_id VARCHAR(24)  NOT NULL,

    sku_public_id    VARCHAR(24)  NOT NULL REFERENCES ${tenantSchema}.medicine_sku (sku_public_id),
    batch_public_id  VARCHAR(24)  NOT NULL REFERENCES ${tenantSchema}.batch (batch_public_id),
    location_id      VARCHAR(32)  NOT NULL REFERENCES ${tenantSchema}.stock_location (location_id),

    -- Positive in, negative out. Always base units.
    qty_delta        INTEGER      NOT NULL,

    reason           VARCHAR(24)  NOT NULL,

    -- The business document that caused the movement. A public id, never a FK:
    -- the causing document may live in another context, or in no context at all
    -- (an OPENING row cites the migration that carried it in).
    ref_type         VARCHAR(24),
    ref_id           VARCHAR(64),

    actor            VARCHAR(48),
    -- When it physically happened vs when we heard about it. Backdated entry of
    -- something that already happened is normal, not an error state.
    occurred_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    recorded_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Offline ordering and idempotency: "<device>:<counter>". A replayed upload
    -- collides on the unique index below and posts nothing twice.
    device_seq       VARCHAR(80),

    correction_of    BIGINT       REFERENCES ${tenantSchema}.stock_ledger (ledger_id),
    note             VARCHAR(300),

    CONSTRAINT ck_ledger_qty_nonzero CHECK (qty_delta <> 0),
    CONSTRAINT ck_ledger_reason CHECK (reason IN (
        'OPENING', 'GRN', 'SALE', 'RETURN_IN', 'RETURN_OUT',
        'TRANSFER_OUT', 'TRANSFER_IN', 'ADJUST', 'CYCLE_COUNT',
        'WARD_ISSUE', 'DAMAGE', 'EXPIRY_QUARANTINE', 'DISPOSAL'))
);

-- Stock Forensics: "show me every movement of this SKU between two dates."
-- The query that costs an Indian pharmacy owner an evening of arguing today.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_ledger_sku_time
    ON ${tenantSchema}.stock_ledger (sku_public_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_ledger_batch
    ON ${tenantSchema}.stock_ledger (batch_public_id);
-- Recall trace and "what did this sale take?" both read this way round.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_ledger_ref
    ON ${tenantSchema}.stock_ledger (ref_type, ref_id) WHERE ref_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_ledger_device_seq
    ON ${tenantSchema}.stock_ledger (device_seq) WHERE device_seq IS NOT NULL;
-- An entry is reversed once. Reversing twice would double the compensation and
-- leave the balance wrong in the direction nobody checks.
CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_ledger_correction_of
    ON ${tenantSchema}.stock_ledger (correction_of) WHERE correction_of IS NOT NULL;

-- The derived cache. Rebuildable from the ledger at any time; maintained in the
-- same transaction as the append so a reader never sees one without the other.
-- `qty` may be negative -- that is the ledger telling you a GRN was not entered,
-- and it becomes a reconciliation task, not a corruption.
CREATE TABLE IF NOT EXISTS ${tenantSchema}.batch_balance (
    sku_public_id   VARCHAR(24) NOT NULL,
    batch_public_id VARCHAR(24) NOT NULL REFERENCES ${tenantSchema}.batch (batch_public_id),
    location_id     VARCHAR(32) NOT NULL REFERENCES ${tenantSchema}.stock_location (location_id),

    qty             BIGINT      NOT NULL DEFAULT 0,
    version         BIGINT      NOT NULL DEFAULT 0,
    updated_at      TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (batch_public_id, location_id)
);

-- "What is in stock for this SKU here?" -- the FEFO allocator's join partner.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_balance_sku_loc
    ON ${tenantSchema}.batch_balance (sku_public_id, location_id) WHERE qty <> 0;

-- ---------------------------------------------------------------
-- Tripwires.
--
-- Both tables below are protected by triggers rather than by convention. The
-- append-only property of a stock ledger is the entire foundation of stock
-- forensics, time-travel, offline merge and controlled-drug compliance; it
-- cannot depend on every future contributor knowing that.
-- ---------------------------------------------------------------

CREATE OR REPLACE FUNCTION ${tenantSchema}.fn_stock_ledger_immutable() RETURNS trigger AS $$
BEGIN
    RAISE EXCEPTION
        'stock_ledger is append-only (attempted %). Reverse the entry with a compensating row carrying correction_of.',
        TG_OP;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_stock_ledger_immutable ON ${tenantSchema}.stock_ledger;
CREATE TRIGGER trg_stock_ledger_immutable
    BEFORE UPDATE OR DELETE ON ${tenantSchema}.stock_ledger
    FOR EACH ROW EXECUTE FUNCTION ${tenantSchema}.fn_stock_ledger_immutable();

-- `batch_balance` is writable only from the ledger-append path, which announces
-- itself by setting a transaction-scoped GUC. SET LOCAL is scoped to the
-- transaction, so the permission cannot leak to the next user of a pooled
-- connection -- and outside a transaction it does not apply at all, which
-- correctly blocks balance writes that were never atomic with an append.
CREATE OR REPLACE FUNCTION ${tenantSchema}.fn_batch_balance_guard() RETURNS trigger AS $$
BEGIN
    IF coalesce(current_setting('sevacare.ledger_append', true), '') <> 'on' THEN
        RAISE EXCEPTION
            'batch_balance is derived from stock_ledger and cannot be written directly (attempted %). Append a ledger entry instead.',
            TG_OP;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_batch_balance_guard ON ${tenantSchema}.batch_balance;
CREATE TRIGGER trg_batch_balance_guard
    BEFORE INSERT OR UPDATE OR DELETE ON ${tenantSchema}.batch_balance
    FOR EACH ROW EXECUTE FUNCTION ${tenantSchema}.fn_batch_balance_guard();

-- =============================================================
-- CAPABILITY  --  the resolved policy knobs (blueprint §10)
-- =============================================================

-- Resolution is platform default -> capability profile -> tenant -> location.
-- Only the tenant layer is stored here; the two above it live in
-- platform.capability_profile and in code, and the location layer arrives with
-- multi-location in Phase 3. Every row is an override someone deliberately made.
CREATE TABLE IF NOT EXISTS ${tenantSchema}.pharmacy_config (
    config_key       VARCHAR(64) PRIMARY KEY,
    config_value     VARCHAR(64) NOT NULL,
    updated_at       TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by       VARCHAR(48)
);
