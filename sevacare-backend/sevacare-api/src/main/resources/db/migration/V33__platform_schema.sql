-- =============================================================
-- V33: The `platform` plane.
--
-- Reference data shared by every tenant: the drug master, its salts, HSN/GST
-- rates, and the capability profile templates that onboarding picks from.
-- Read-only to tenant request flows; written by ops tooling. It lives in its own
-- schema rather than in `public` because `public` holds cross-tenant
-- *operational* tables (tenant_registry, whatsapp_outbox) and this is
-- *reference* data with a completely different change cadence and blast radius.
--
-- The drug master is deliberately EMPTY here. There is no free authoritative
-- Indian drug database, and bad salt mappings poison substitution and
-- interaction features downstream (blueprint R1, the #1 product risk). Seeding
-- waits on the licensed-vs-curated decision in §20.2. The capability profiles
-- below are our own data, so they are seeded now.
--
-- The tenant catalog stays sovereign: a pharmacy may sell an SKU this master has
-- never heard of. Platform linkage enriches, it never gates. Nothing in this
-- schema is on the critical path of a sale.
-- =============================================================

CREATE SCHEMA IF NOT EXISTS platform;

-- ---------------------------------------------------------------
-- Salts (molecules). The unit of substitution and interaction, not the brand.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS platform.salt (
    salt_public_id  VARCHAR(24)  PRIMARY KEY,
    salt_name       VARCHAR(160) NOT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_platform_salt_name
    ON platform.salt (lower(salt_name));

-- ---------------------------------------------------------------
-- Drug master.
--
-- `confidence` is load-bearing rather than decorative: interaction and
-- substitution features ship at SUGGEST until the data behind them earns trust,
-- and this column is how a caller knows what it is standing on. `source` and
-- `source_version` exist so a bad import can be identified and rolled back by
-- provenance instead of by guesswork.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS platform.drug_master (
    drug_public_id      VARCHAR(24)  PRIMARY KEY,
    brand_name          VARCHAR(200) NOT NULL,
    manufacturer        VARCHAR(200),
    dosage_form         VARCHAR(40),
    strength            VARCHAR(80),
    pack_size           VARCHAR(40),

    -- 'H', 'H1', 'X', 'G', 'OTC'. Tenant-overridable on their own SKU.
    schedule_class      VARCHAR(8),
    hsn_code            VARCHAR(12),

    -- Money is integer minor units. A floating-point rupee is a bug waiting
    -- for an auditor. Null where DPCO sets no ceiling for this drug.
    ceiling_price_paise BIGINT,

    confidence          VARCHAR(16)  NOT NULL DEFAULT 'UNVERIFIED',
    source              VARCHAR(40),
    source_version      VARCHAR(40),
    active              BOOLEAN      NOT NULL DEFAULT true,
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT ck_platform_drug_confidence
        CHECK (confidence IN ('VERIFIED', 'CURATED', 'IMPORTED', 'UNVERIFIED')),
    CONSTRAINT ck_platform_drug_ceiling_nonneg
        CHECK (ceiling_price_paise IS NULL OR ceiling_price_paise >= 0)
);

CREATE INDEX IF NOT EXISTS idx_platform_drug_brand
    ON platform.drug_master (lower(brand_name));

-- A drug is its composition: one brand, one or more salts at a strength.
CREATE TABLE IF NOT EXISTS platform.drug_salt (
    drug_public_id VARCHAR(24) NOT NULL REFERENCES platform.drug_master (drug_public_id) ON DELETE CASCADE,
    salt_public_id VARCHAR(24) NOT NULL REFERENCES platform.salt (salt_public_id) ON DELETE RESTRICT,
    strength       VARCHAR(80),
    PRIMARY KEY (drug_public_id, salt_public_id)
);

-- Substitution ("what else has this composition?") reads this way round.
CREATE INDEX IF NOT EXISTS idx_platform_drug_salt_by_salt
    ON platform.drug_salt (salt_public_id);

-- ---------------------------------------------------------------
-- HSN -> GST. Rates are basis points (500 = 5.00%), never a float: a rounding
-- error here is a tax filing error.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS platform.hsn_gst_rate (
    hsn_code       VARCHAR(12) NOT NULL,
    gst_rate_bp    INTEGER     NOT NULL,
    effective_from DATE        NOT NULL,
    effective_to   DATE,
    PRIMARY KEY (hsn_code, effective_from),

    CONSTRAINT ck_platform_gst_rate_range CHECK (gst_rate_bp BETWEEN 0 AND 10000),
    CONSTRAINT ck_platform_gst_effective  CHECK (effective_to IS NULL OR effective_to > effective_from)
);

-- ---------------------------------------------------------------
-- Capability profile templates.
--
-- Onboarding stays a single question -- "what are you?" -- and the answer sets
-- which contexts are on and how strict the policies start. Profiles are
-- templates, not cages: a tenant's resolved config may diverge afterwards, so
-- these rows are a starting point that is never read again at runtime.
--
-- Every policy is an OFF/SUGGEST/ENFORCE knob. The one deliberate exception,
-- with no OFF setting anywhere, is dispensing from an expired batch.
-- ---------------------------------------------------------------
CREATE TABLE IF NOT EXISTS platform.capability_profile (
    profile_key     VARCHAR(32)  PRIMARY KEY,
    display_name    VARCHAR(80)  NOT NULL,
    description     VARCHAR(300),
    enabled_modules JSONB        NOT NULL,
    policy_defaults JSONB        NOT NULL DEFAULT '{}'::jsonb,
    sort_order      SMALLINT     NOT NULL DEFAULT 0
);

INSERT INTO platform.capability_profile
    (profile_key, display_name, description, enabled_modules, policy_defaults, sort_order)
VALUES
    ('MEDICAL_STORE', 'Medical store',
     'POS-first standalone store. No prescription queue, no wards.',
     '["catalog","inventory","fulfillment","procurement","returns","billing","compliance"]',
     '{"batch_on_sale_line":"SUGGEST","rx_required_for_schedule_h":"SUGGEST","expired_batch_dispense":"ENFORCE","above_ceiling_price_sale":"SUGGEST"}',
     1),
    ('CLINIC_DISPENSARY', 'Clinic dispensary',
     'Consult to dispense handoff is the hero flow.',
     '["catalog","inventory","fulfillment","procurement","returns","billing","compliance","rx_queue"]',
     '{"batch_on_sale_line":"SUGGEST","rx_required_for_schedule_h":"SUGGEST","expired_batch_dispense":"ENFORCE","above_ceiling_price_sale":"SUGGEST"}',
     2),
    ('HOSPITAL_PHARMACY', 'Hospital pharmacy',
     'Wards, indents and sub-stores. Role separation, stricter defaults.',
     '["catalog","inventory","fulfillment","procurement","returns","billing","compliance","rx_queue","wards","formulary"]',
     '{"batch_on_sale_line":"ENFORCE","rx_required_for_schedule_h":"ENFORCE","expired_batch_dispense":"ENFORCE","above_ceiling_price_sale":"ENFORCE"}',
     3),
    ('PHARMACY_CHAIN', 'Pharmacy chain',
     'Transfers, central purchasing and cross-store views.',
     '["catalog","inventory","fulfillment","procurement","returns","billing","compliance","rx_queue","transfers","central_purchasing"]',
     '{"batch_on_sale_line":"ENFORCE","rx_required_for_schedule_h":"SUGGEST","expired_batch_dispense":"ENFORCE","above_ceiling_price_sale":"SUGGEST"}',
     4),
    ('CORPORATE_ENTERPRISE', 'Corporate enterprise',
     'Three-way match, approval chains and API access.',
     '["catalog","inventory","fulfillment","procurement","returns","billing","compliance","rx_queue","transfers","central_purchasing","approvals","api_access"]',
     '{"batch_on_sale_line":"ENFORCE","rx_required_for_schedule_h":"ENFORCE","expired_batch_dispense":"ENFORCE","above_ceiling_price_sale":"ENFORCE"}',
     5)
ON CONFLICT (profile_key) DO NOTHING;
