-- =============================================================
-- V6: Pharmacy — a real starter catalog.
--
-- Every tenant schema begins with zero medicines (V3 seeds only
-- stock_location), so a fresh counter's search box has nothing to find.
-- This ships a common Indian OTC/Rx catalog plus one sample supplier and
-- opening stock, so a pharmacy-enabled tenant can search and sell
-- immediately rather than starting from an empty shelf.
--
-- Every insert below is gated on the tenant actually having pharmacy
-- enabled at the moment this migration runs (checked once into a GUC,
-- not per statement). A hospital-only tenant gets none of this — seeding
-- fake stock movements into a pharmacy nobody turned on would corrupt the
-- one signal ("has this ledger ever moved") that lets an unused pharmacy
-- be switched back off cleanly. A tenant that enables pharmacy *after*
-- this migration already ran starts with an empty catalog, exactly like
-- today, and populates it via GRN like any other store.
--
-- Ledger/balance writes below run inside SET LOCAL sevacare.ledger_append
-- = 'on', the same GUC StockLedgerService itself sets — the setting holds
-- for every statement in this transaction and is gone the moment the
-- migration commits.
-- =============================================================

DO $$
DECLARE enabled boolean;
BEGIN
    SELECT (pharmacy_profile_key IS NOT NULL) INTO enabled
    FROM public.tenant_registry WHERE tenant_public_id = '${tenantPublicId}';
    PERFORM set_config('sevacare.seed_pharmacy_enabled', COALESCE(enabled, false)::text, true);
END $$;

SET LOCAL sevacare.ledger_append = 'on';

INSERT INTO ${tenantSchema}.supplier
    (supplier_public_id, tenant_public_id, supplier_name, mobile_number, gstin, city, note)
SELECT 'SUP-SEED01', '${tenantPublicId}', 'Apollo Pharma Distributors', '9999999999', '27AAAAA0000A1Z5', 'Mumbai',
       'Seed supplier for the starter catalog — replace with your real distributor.'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (supplier_public_id) DO NOTHING;


-- 1. Paracetamol 500mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0001', '${tenantPublicId}', 'Paracetamol 500mg', 'Cipla', 'TABLET', '500mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0001', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0001', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0001', '${tenantPublicId}', 'SKU-SEED0001', 'SEED-BATCH', DATE '2027-12-31', 150,
       105, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0001', 'BATCH-SEED0001', 'COUNTER', 300, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0001', 'BATCH-SEED0001', 'COUNTER', 300
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 2. Paracetamol 650mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0002', '${tenantPublicId}', 'Paracetamol 650mg', 'GSK', 'TABLET', '650mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0002', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0002', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0002', '${tenantPublicId}', 'SKU-SEED0002', 'SEED-BATCH', DATE '2027-12-31', 200,
       140, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0002', 'BATCH-SEED0002', 'COUNTER', 300, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0002', 'BATCH-SEED0002', 'COUNTER', 300
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 3. Cetirizine 10mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0003', '${tenantPublicId}', 'Cetirizine 10mg', 'Dr Reddy''s', 'TABLET', '10mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0003', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0003', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0003', '${tenantPublicId}', 'SKU-SEED0003', 'SEED-BATCH', DATE '2027-12-31', 120,
       84, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0003', 'BATCH-SEED0003', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0003', 'BATCH-SEED0003', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 4. Levocetirizine 5mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0004', '${tenantPublicId}', 'Levocetirizine 5mg', 'Sun Pharma', 'TABLET', '5mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0004', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0004', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0004', '${tenantPublicId}', 'SKU-SEED0004', 'SEED-BATCH', DATE '2027-12-31', 150,
       105, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0004', 'BATCH-SEED0004', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0004', 'BATCH-SEED0004', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 5. Ibuprofen 400mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0005', '${tenantPublicId}', 'Ibuprofen 400mg', 'Abbott', 'TABLET', '400mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0005', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0005', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0005', '${tenantPublicId}', 'SKU-SEED0005', 'SEED-BATCH', DATE '2027-12-31', 180,
       125, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0005', 'BATCH-SEED0005', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0005', 'BATCH-SEED0005', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 6. Diclofenac 50mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0006', '${tenantPublicId}', 'Diclofenac 50mg', 'Novartis', 'TABLET', '50mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0006', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0006', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0006', '${tenantPublicId}', 'SKU-SEED0006', 'SEED-BATCH', DATE '2027-12-31', 200,
       140, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0006', 'BATCH-SEED0006', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0006', 'BATCH-SEED0006', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 7. Aceclofenac 100mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0007', '${tenantPublicId}', 'Aceclofenac 100mg', 'Cipla', 'TABLET', '100mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0007', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0007', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0007', '${tenantPublicId}', 'SKU-SEED0007', 'SEED-BATCH', DATE '2027-12-31', 220,
       154, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0007', 'BATCH-SEED0007', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0007', 'BATCH-SEED0007', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 8. Multivitamin Tablet
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0008', '${tenantPublicId}', 'Multivitamin Tablet', 'Pfizer', 'TABLET', '1 tab',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0008', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0008', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0008', '${tenantPublicId}', 'SKU-SEED0008', 'SEED-BATCH', DATE '2027-12-31', 250,
       175, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0008', 'BATCH-SEED0008', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0008', 'BATCH-SEED0008', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 9. Calcium + Vitamin D3
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0009', '${tenantPublicId}', 'Calcium + Vitamin D3', 'Mankind', 'TABLET', '500mg+250IU',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0009', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0009', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0009', '${tenantPublicId}', 'SKU-SEED0009', 'SEED-BATCH', DATE '2027-12-31', 300,
       210, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0009', 'BATCH-SEED0009', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0009', 'BATCH-SEED0009', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 10. Iron + Folic Acid
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0010', '${tenantPublicId}', 'Iron + Folic Acid', 'Zydus', 'TABLET', '100mg+0.5mg',
       'TABLET', NULL, '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0010', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0010', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0010', '${tenantPublicId}', 'SKU-SEED0010', 'SEED-BATCH', DATE '2027-12-31', 200,
       140, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0010', 'BATCH-SEED0010', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0010', 'BATCH-SEED0010', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 11. Vitamin C 500mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0011', '${tenantPublicId}', 'Vitamin C 500mg', 'Mankind', 'TABLET', '500mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0011', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0011', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0011', '${tenantPublicId}', 'SKU-SEED0011', 'SEED-BATCH', DATE '2027-12-31', 250,
       175, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0011', 'BATCH-SEED0011', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0011', 'BATCH-SEED0011', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 12. Zinc 50mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0012', '${tenantPublicId}', 'Zinc 50mg', 'Mankind', 'TABLET', '50mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0012', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0012', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0012', '${tenantPublicId}', 'SKU-SEED0012', 'SEED-BATCH', DATE '2027-12-31', 220,
       154, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0012', 'BATCH-SEED0012', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0012', 'BATCH-SEED0012', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 13. B-Complex Tablet
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0013', '${tenantPublicId}', 'B-Complex Tablet', 'Alkem', 'TABLET', '1 tab',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0013', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0013', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0013', '${tenantPublicId}', 'SKU-SEED0013', 'SEED-BATCH', DATE '2027-12-31', 200,
       140, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0013', 'BATCH-SEED0013', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0013', 'BATCH-SEED0013', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 14. Antacid Tablet
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0014', '${tenantPublicId}', 'Antacid Tablet', 'Abbott', 'TABLET', '1 tab',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0014', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0014', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0014', '${tenantPublicId}', 'SKU-SEED0014', 'SEED-BATCH', DATE '2027-12-31', 150,
       105, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0014', 'BATCH-SEED0014', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0014', 'BATCH-SEED0014', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 15. Ondansetron 4mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0015', '${tenantPublicId}', 'Ondansetron 4mg', 'Cipla', 'TABLET', '4mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0015', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0015', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0015', '${tenantPublicId}', 'SKU-SEED0015', 'SEED-BATCH', DATE '2027-12-31', 350,
       244, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0015', 'BATCH-SEED0015', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0015', 'BATCH-SEED0015', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 16. Loperamide 2mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0016', '${tenantPublicId}', 'Loperamide 2mg', 'Johnson & Johnson', 'TABLET', '2mg',
       'TABLET', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0016', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0016', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0016', '${tenantPublicId}', 'SKU-SEED0016', 'SEED-BATCH', DATE '2027-12-31', 180,
       125, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0016', 'BATCH-SEED0016', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0016', 'BATCH-SEED0016', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 17. Aspirin 75mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0017', '${tenantPublicId}', 'Aspirin 75mg', 'Bayer', 'TABLET', '75mg',
       'TABLET', NULL, '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0017', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0017', 'Strip of 14', 14, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0017', '${tenantPublicId}', 'SKU-SEED0017', 'SEED-BATCH', DATE '2027-12-31', 100,
       70, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0017', 'BATCH-SEED0017', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0017', 'BATCH-SEED0017', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 18. Azithromycin 500mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0018', '${tenantPublicId}', 'Azithromycin 500mg', 'Alembic', 'TABLET', '500mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0018', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0018', 'Strip of 3', 3, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0018', '${tenantPublicId}', 'SKU-SEED0018', 'SEED-BATCH', DATE '2027-12-31', 900,
       630, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0018', 'BATCH-SEED0018', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0018', 'BATCH-SEED0018', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 19. Amoxicillin 500mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0019', '${tenantPublicId}', 'Amoxicillin 500mg', 'Cipla', 'TABLET', '500mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0019', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0019', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0019', '${tenantPublicId}', 'SKU-SEED0019', 'SEED-BATCH', DATE '2027-12-31', 700,
       489, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0019', 'BATCH-SEED0019', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0019', 'BATCH-SEED0019', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 20. Amoxicillin + Clavulanate 625mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0020', '${tenantPublicId}', 'Amoxicillin + Clavulanate 625mg', 'GSK', 'TABLET', '625mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0020', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0020', 'Strip of 6', 6, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0020', '${tenantPublicId}', 'SKU-SEED0020', 'SEED-BATCH', DATE '2027-12-31', 1200,
       840, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0020', 'BATCH-SEED0020', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0020', 'BATCH-SEED0020', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 21. Ciprofloxacin 500mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0021', '${tenantPublicId}', 'Ciprofloxacin 500mg', 'Bayer', 'TABLET', '500mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0021', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0021', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0021', '${tenantPublicId}', 'SKU-SEED0021', 'SEED-BATCH', DATE '2027-12-31', 800,
       560, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0021', 'BATCH-SEED0021', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0021', 'BATCH-SEED0021', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 22. Doxycycline 100mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0022', '${tenantPublicId}', 'Doxycycline 100mg', 'Sun Pharma', 'TABLET', '100mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0022', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0022', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0022', '${tenantPublicId}', 'SKU-SEED0022', 'SEED-BATCH', DATE '2027-12-31', 500,
       350, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0022', 'BATCH-SEED0022', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0022', 'BATCH-SEED0022', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 23. Metronidazole 400mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0023', '${tenantPublicId}', 'Metronidazole 400mg', 'Cipla', 'TABLET', '400mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0023', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0023', 'Strip of 15', 15, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0023', '${tenantPublicId}', 'SKU-SEED0023', 'SEED-BATCH', DATE '2027-12-31', 300,
       210, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0023', 'BATCH-SEED0023', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0023', 'BATCH-SEED0023', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 24. Pantoprazole 40mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0024', '${tenantPublicId}', 'Pantoprazole 40mg', 'Sun Pharma', 'TABLET', '40mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0024', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0024', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0024', '${tenantPublicId}', 'SKU-SEED0024', 'SEED-BATCH', DATE '2027-12-31', 350,
       244, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0024', 'BATCH-SEED0024', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0024', 'BATCH-SEED0024', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 25. Domperidone 10mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0025', '${tenantPublicId}', 'Domperidone 10mg', 'Cipla', 'TABLET', '10mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0025', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0025', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0025', '${tenantPublicId}', 'SKU-SEED0025', 'SEED-BATCH', DATE '2027-12-31', 250,
       175, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0025', 'BATCH-SEED0025', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0025', 'BATCH-SEED0025', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 26. Rabeprazole 20mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0026', '${tenantPublicId}', 'Rabeprazole 20mg', 'Alkem', 'TABLET', '20mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0026', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0026', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0026', '${tenantPublicId}', 'SKU-SEED0026', 'SEED-BATCH', DATE '2027-12-31', 400,
       280, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0026', 'BATCH-SEED0026', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0026', 'BATCH-SEED0026', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 27. Metformin 500mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0027', '${tenantPublicId}', 'Metformin 500mg', 'USV', 'TABLET', '500mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0027', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0027', 'Strip of 15', 15, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0027', '${tenantPublicId}', 'SKU-SEED0027', 'SEED-BATCH', DATE '2027-12-31', 200,
       140, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0027', 'BATCH-SEED0027', 'COUNTER', 300, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0027', 'BATCH-SEED0027', 'COUNTER', 300
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 28. Metformin 1000mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0028', '${tenantPublicId}', 'Metformin 1000mg', 'USV', 'TABLET', '1000mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0028', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0028', 'Strip of 15', 15, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0028', '${tenantPublicId}', 'SKU-SEED0028', 'SEED-BATCH', DATE '2027-12-31', 300,
       210, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0028', 'BATCH-SEED0028', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0028', 'BATCH-SEED0028', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 29. Glimepiride 2mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0029', '${tenantPublicId}', 'Glimepiride 2mg', 'Sanofi', 'TABLET', '2mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0029', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0029', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0029', '${tenantPublicId}', 'SKU-SEED0029', 'SEED-BATCH', DATE '2027-12-31', 400,
       280, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0029', 'BATCH-SEED0029', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0029', 'BATCH-SEED0029', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 30. Amlodipine 5mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0030', '${tenantPublicId}', 'Amlodipine 5mg', 'Pfizer', 'TABLET', '5mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0030', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0030', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0030', '${tenantPublicId}', 'SKU-SEED0030', 'SEED-BATCH', DATE '2027-12-31', 200,
       140, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0030', 'BATCH-SEED0030', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0030', 'BATCH-SEED0030', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 31. Atorvastatin 10mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0031', '${tenantPublicId}', 'Atorvastatin 10mg', 'Pfizer', 'TABLET', '10mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0031', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0031', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0031', '${tenantPublicId}', 'SKU-SEED0031', 'SEED-BATCH', DATE '2027-12-31', 350,
       244, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0031', 'BATCH-SEED0031', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0031', 'BATCH-SEED0031', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 32. Atorvastatin 20mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0032', '${tenantPublicId}', 'Atorvastatin 20mg', 'Pfizer', 'TABLET', '20mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0032', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0032', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0032', '${tenantPublicId}', 'SKU-SEED0032', 'SEED-BATCH', DATE '2027-12-31', 500,
       350, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0032', 'BATCH-SEED0032', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0032', 'BATCH-SEED0032', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 33. Losartan 50mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0033', '${tenantPublicId}', 'Losartan 50mg', 'Cipla', 'TABLET', '50mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0033', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0033', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0033', '${tenantPublicId}', 'SKU-SEED0033', 'SEED-BATCH', DATE '2027-12-31', 300,
       210, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0033', 'BATCH-SEED0033', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0033', 'BATCH-SEED0033', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 34. Telmisartan 40mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0034', '${tenantPublicId}', 'Telmisartan 40mg', 'Glenmark', 'TABLET', '40mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0034', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0034', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0034', '${tenantPublicId}', 'SKU-SEED0034', 'SEED-BATCH', DATE '2027-12-31', 400,
       280, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0034', 'BATCH-SEED0034', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0034', 'BATCH-SEED0034', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 35. Clopidogrel 75mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0035', '${tenantPublicId}', 'Clopidogrel 75mg', 'Sanofi', 'TABLET', '75mg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0035', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0035', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0035', '${tenantPublicId}', 'SKU-SEED0035', 'SEED-BATCH', DATE '2027-12-31', 600,
       420, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0035', 'BATCH-SEED0035', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0035', 'BATCH-SEED0035', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 36. Levothyroxine 50mcg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0036', '${tenantPublicId}', 'Levothyroxine 50mcg', 'Abbott', 'TABLET', '50mcg',
       'TABLET', 'H', '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0036', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0036', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0036', '${tenantPublicId}', 'SKU-SEED0036', 'SEED-BATCH', DATE '2027-12-31', 250,
       175, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0036', 'BATCH-SEED0036', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0036', 'BATCH-SEED0036', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 37. Montelukast 10mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0037', '${tenantPublicId}', 'Montelukast 10mg', 'MSD', 'TABLET', '10mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0037', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0037', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0037', '${tenantPublicId}', 'SKU-SEED0037', 'SEED-BATCH', DATE '2027-12-31', 700,
       489, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0037', 'BATCH-SEED0037', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0037', 'BATCH-SEED0037', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 38. Famotidine 40mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0038', '${tenantPublicId}', 'Famotidine 40mg', 'Zydus', 'TABLET', '40mg',
       'TABLET', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0038', 'Tablet', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0038', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0038', '${tenantPublicId}', 'SKU-SEED0038', 'SEED-BATCH', DATE '2027-12-31', 300,
       210, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0038', 'BATCH-SEED0038', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0038', 'BATCH-SEED0038', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 39. Omeprazole 20mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0039', '${tenantPublicId}', 'Omeprazole 20mg', 'Dr Reddy''s', 'CAPSULE', '20mg',
       'CAPSULE', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0039', 'Capsule', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0039', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0039', '${tenantPublicId}', 'SKU-SEED0039', 'SEED-BATCH', DATE '2027-12-31', 300,
       210, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0039', 'BATCH-SEED0039', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0039', 'BATCH-SEED0039', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 40. Amoxicillin 500mg Capsule
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0040', '${tenantPublicId}', 'Amoxicillin 500mg Capsule', 'Cipla', 'CAPSULE', '500mg',
       'CAPSULE', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0040', 'Capsule', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0040', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0040', '${tenantPublicId}', 'SKU-SEED0040', 'SEED-BATCH', DATE '2027-12-31', 700,
       489, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0040', 'BATCH-SEED0040', 'COUNTER', 150, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0040', 'BATCH-SEED0040', 'COUNTER', 150
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 41. Doxycycline 100mg Capsule
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0041', '${tenantPublicId}', 'Doxycycline 100mg Capsule', 'Sun Pharma', 'CAPSULE', '100mg',
       'CAPSULE', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0041', 'Capsule', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0041', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0041', '${tenantPublicId}', 'SKU-SEED0041', 'SEED-BATCH', DATE '2027-12-31', 500,
       350, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0041', 'BATCH-SEED0041', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0041', 'BATCH-SEED0041', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 42. Fluconazole 150mg
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0042', '${tenantPublicId}', 'Fluconazole 150mg', 'Pfizer', 'CAPSULE', '150mg',
       'CAPSULE', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0042', 'Capsule', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0042', 'Strip of 1', 1, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0042', '${tenantPublicId}', 'SKU-SEED0042', 'SEED-BATCH', DATE '2027-12-31', 900,
       630, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0042', 'BATCH-SEED0042', 'COUNTER', 60, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0042', 'BATCH-SEED0042', 'COUNTER', 60
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 43. Multivitamin Capsule
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0043', '${tenantPublicId}', 'Multivitamin Capsule', 'Pfizer', 'CAPSULE', '1 cap',
       'CAPSULE', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0043', 'Capsule', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0043', 'Strip of 10', 10, true, false, 1
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0043', '${tenantPublicId}', 'SKU-SEED0043', 'SEED-BATCH', DATE '2027-12-31', 250,
       175, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0043', 'BATCH-SEED0043', 'COUNTER', 200, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0043', 'BATCH-SEED0043', 'COUNTER', 200
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 44. Paracetamol Syrup 60ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0044', '${tenantPublicId}', 'Paracetamol Syrup 60ml', 'GSK', 'SYRUP', '60ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0044', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0044', '${tenantPublicId}', 'SKU-SEED0044', 'SEED-BATCH', DATE '2027-12-31', 200,
       140, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0044', 'BATCH-SEED0044', 'COUNTER', 40, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0044', 'BATCH-SEED0044', 'COUNTER', 40
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 45. Cough Syrup (Ambroxol) 100ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0045', '${tenantPublicId}', 'Cough Syrup (Ambroxol) 100ml', 'Cipla', 'SYRUP', '100ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0045', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0045', '${tenantPublicId}', 'SKU-SEED0045', 'SEED-BATCH', DATE '2027-12-31', 150,
       105, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0045', 'BATCH-SEED0045', 'COUNTER', 40, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0045', 'BATCH-SEED0045', 'COUNTER', 40
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 46. Cetirizine Syrup 60ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0046', '${tenantPublicId}', 'Cetirizine Syrup 60ml', 'Dr Reddy''s', 'SYRUP', '60ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0046', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0046', '${tenantPublicId}', 'SKU-SEED0046', 'SEED-BATCH', DATE '2027-12-31', 180,
       125, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0046', 'BATCH-SEED0046', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0046', 'BATCH-SEED0046', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 47. Amoxicillin Syrup 60ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0047', '${tenantPublicId}', 'Amoxicillin Syrup 60ml', 'Cipla', 'SYRUP', '60ml',
       'ML', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0047', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0047', '${tenantPublicId}', 'SKU-SEED0047', 'SEED-BATCH', DATE '2027-12-31', 250,
       175, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0047', 'BATCH-SEED0047', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0047', 'BATCH-SEED0047', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 48. Domperidone Syrup 30ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0048', '${tenantPublicId}', 'Domperidone Syrup 30ml', 'Cipla', 'SYRUP', '30ml',
       'ML', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0048', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0048', '${tenantPublicId}', 'SKU-SEED0048', 'SEED-BATCH', DATE '2027-12-31', 300,
       210, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0048', 'BATCH-SEED0048', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0048', 'BATCH-SEED0048', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 49. Metronidazole Syrup 60ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0049', '${tenantPublicId}', 'Metronidazole Syrup 60ml', 'Cipla', 'SYRUP', '60ml',
       'ML', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0049', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0049', '${tenantPublicId}', 'SKU-SEED0049', 'SEED-BATCH', DATE '2027-12-31', 220,
       154, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0049', 'BATCH-SEED0049', 'COUNTER', 20, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0049', 'BATCH-SEED0049', 'COUNTER', 20
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 50. Antacid Syrup 170ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0050', '${tenantPublicId}', 'Antacid Syrup 170ml', 'Abbott', 'SYRUP', '170ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0050', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0050', '${tenantPublicId}', 'SKU-SEED0050', 'SEED-BATCH', DATE '2027-12-31', 130,
       91, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0050', 'BATCH-SEED0050', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0050', 'BATCH-SEED0050', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 51. Iron Syrup 200ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0051', '${tenantPublicId}', 'Iron Syrup 200ml', 'Zydus', 'SYRUP', '200ml',
       'ML', NULL, '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0051', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0051', '${tenantPublicId}', 'SKU-SEED0051', 'SEED-BATCH', DATE '2027-12-31', 120,
       84, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0051', 'BATCH-SEED0051', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0051', 'BATCH-SEED0051', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 52. Multivitamin Syrup 200ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0052', '${tenantPublicId}', 'Multivitamin Syrup 200ml', 'Mankind', 'SYRUP', '200ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0052', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0052', '${tenantPublicId}', 'SKU-SEED0052', 'SEED-BATCH', DATE '2027-12-31', 140,
       98, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0052', 'BATCH-SEED0052', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0052', 'BATCH-SEED0052', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 53. Moxifloxacin Eye Drops 5ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0053', '${tenantPublicId}', 'Moxifloxacin Eye Drops 5ml', 'Sun Pharma', 'DROPS', '5ml',
       'ML', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0053', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0053', '${tenantPublicId}', 'SKU-SEED0053', 'SEED-BATCH', DATE '2027-12-31', 1600,
       1120, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0053', 'BATCH-SEED0053', 'COUNTER', 20, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0053', 'BATCH-SEED0053', 'COUNTER', 20
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 54. Ciprofloxacin Ear Drops 10ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0054', '${tenantPublicId}', 'Ciprofloxacin Ear Drops 10ml', 'Cipla', 'DROPS', '10ml',
       'ML', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0054', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0054', '${tenantPublicId}', 'SKU-SEED0054', 'SEED-BATCH', DATE '2027-12-31', 1200,
       840, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0054', 'BATCH-SEED0054', 'COUNTER', 20, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0054', 'BATCH-SEED0054', 'COUNTER', 20
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 55. Xylometazoline Nasal Drops 10ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0055', '${tenantPublicId}', 'Xylometazoline Nasal Drops 10ml', 'Sun Pharma', 'DROPS', '10ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0055', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0055', '${tenantPublicId}', 'SKU-SEED0055', 'SEED-BATCH', DATE '2027-12-31', 800,
       560, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0055', 'BATCH-SEED0055', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0055', 'BATCH-SEED0055', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 56. Multivitamin Drops 15ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0056', '${tenantPublicId}', 'Multivitamin Drops 15ml', 'Mankind', 'DROPS', '15ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0056', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0056', '${tenantPublicId}', 'SKU-SEED0056', 'SEED-BATCH', DATE '2027-12-31', 900,
       630, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0056', 'BATCH-SEED0056', 'COUNTER', 20, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0056', 'BATCH-SEED0056', 'COUNTER', 20
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 57. Betadine Ointment 20g
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0057', '${tenantPublicId}', 'Betadine Ointment 20g', 'Win-Medicare', 'OINTMENT', '20g',
       'GM', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0057', 'Gm', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0057', '${tenantPublicId}', 'SKU-SEED0057', 'SEED-BATCH', DATE '2027-12-31', 900,
       630, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0057', 'BATCH-SEED0057', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0057', 'BATCH-SEED0057', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 58. Diclofenac Gel 30g
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0058', '${tenantPublicId}', 'Diclofenac Gel 30g', 'Novartis', 'GEL', '30g',
       'GM', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0058', 'Gm', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0058', '${tenantPublicId}', 'SKU-SEED0058', 'SEED-BATCH', DATE '2027-12-31', 1100,
       770, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0058', 'BATCH-SEED0058', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0058', 'BATCH-SEED0058', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 59. Clotrimazole Cream 20g
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0059', '${tenantPublicId}', 'Clotrimazole Cream 20g', 'Bayer', 'CREAM', '20g',
       'GM', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0059', 'Gm', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0059', '${tenantPublicId}', 'SKU-SEED0059', 'SEED-BATCH', DATE '2027-12-31', 800,
       560, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0059', 'BATCH-SEED0059', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0059', 'BATCH-SEED0059', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 60. Calamine Lotion 60ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0060', '${tenantPublicId}', 'Calamine Lotion 60ml', 'Piramal', 'LOTION', '60ml',
       'ML', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0060', 'Ml', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0060', '${tenantPublicId}', 'SKU-SEED0060', 'SEED-BATCH', DATE '2027-12-31', 700,
       489, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0060', 'BATCH-SEED0060', 'COUNTER', 25, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0060', 'BATCH-SEED0060', 'COUNTER', 25
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 61. Mupirocin Ointment 5g
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0061', '${tenantPublicId}', 'Mupirocin Ointment 5g', 'GSK', 'OINTMENT', '5g',
       'GM', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0061', 'Gm', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0061', '${tenantPublicId}', 'SKU-SEED0061', 'SEED-BATCH', DATE '2027-12-31', 1000,
       700, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0061', 'BATCH-SEED0061', 'COUNTER', 20, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0061', 'BATCH-SEED0061', 'COUNTER', 20
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 62. Diclofenac Injection (amp)
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0062', '${tenantPublicId}', 'Diclofenac Injection (amp)', 'Novartis', 'INJECTION', '3ml amp',
       'UNIT', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0062', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0062', '${tenantPublicId}', 'SKU-SEED0062', 'SEED-BATCH', DATE '2027-12-31', 2000,
       1400, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0062', 'BATCH-SEED0062', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0062', 'BATCH-SEED0062', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 63. Vitamin B12 Injection (amp)
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0063', '${tenantPublicId}', 'Vitamin B12 Injection (amp)', 'Mankind', 'INJECTION', '1ml amp',
       'UNIT', 'H', '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0063', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0063', '${tenantPublicId}', 'SKU-SEED0063', 'SEED-BATCH', DATE '2027-12-31', 1500,
       1050, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0063', 'BATCH-SEED0063', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0063', 'BATCH-SEED0063', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 64. ORS Sachet
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0064', '${tenantPublicId}', 'ORS Sachet', 'FDC', 'POWDER', '21.8g',
       'UNIT', NULL, '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0064', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0064', '${tenantPublicId}', 'SKU-SEED0064', 'SEED-BATCH', DATE '2027-12-31', 1500,
       1050, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0064', 'BATCH-SEED0064', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0064', 'BATCH-SEED0064', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 65. Electral Powder Sachet
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0065', '${tenantPublicId}', 'Electral Powder Sachet', 'FDC', 'POWDER', '21.8g',
       'UNIT', NULL, '3004', 500, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0065', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0065', '${tenantPublicId}', 'SKU-SEED0065', 'SEED-BATCH', DATE '2027-12-31', 1500,
       1050, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0065', 'BATCH-SEED0065', 'COUNTER', 100, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0065', 'BATCH-SEED0065', 'COUNTER', 100
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 66. Antacid Powder Sachet
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0066', '${tenantPublicId}', 'Antacid Powder Sachet', 'Abbott', 'POWDER', '5g',
       'UNIT', NULL, '3004', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0066', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0066', '${tenantPublicId}', 'SKU-SEED0066', 'SEED-BATCH', DATE '2027-12-31', 500,
       350, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0066', 'BATCH-SEED0066', 'COUNTER', 60, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0066', 'BATCH-SEED0066', 'COUNTER', 60
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 67. Cotton Roll 100g
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0067', '${tenantPublicId}', 'Cotton Roll 100g', 'Johnson & Johnson', 'OTHER', '100g',
       'UNIT', NULL, '3005', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0067', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0067', '${tenantPublicId}', 'SKU-SEED0067', 'SEED-BATCH', DATE '2027-12-31', 6000,
       4200, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0067', 'BATCH-SEED0067', 'COUNTER', 20, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0067', 'BATCH-SEED0067', 'COUNTER', 20
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 68. Gauze Bandage 6cm
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0068', '${tenantPublicId}', 'Gauze Bandage 6cm', 'Johnson & Johnson', 'OTHER', '6cm x 4m',
       'UNIT', NULL, '3005', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0068', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0068', '${tenantPublicId}', 'SKU-SEED0068', 'SEED-BATCH', DATE '2027-12-31', 2500,
       1750, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0068', 'BATCH-SEED0068', 'COUNTER', 30, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0068', 'BATCH-SEED0068', 'COUNTER', 30
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 69. Adhesive Bandage Box (Band-Aid)
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0069', '${tenantPublicId}', 'Adhesive Bandage Box (Band-Aid)', 'Johnson & Johnson', 'OTHER', '100 strips',
       'UNIT', NULL, '3005', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0069', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0069', '${tenantPublicId}', 'SKU-SEED0069', 'SEED-BATCH', DATE '2027-12-31', 9000,
       6300, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0069', 'BATCH-SEED0069', 'COUNTER', 15, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0069', 'BATCH-SEED0069', 'COUNTER', 15
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 70. Hand Sanitizer 500ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0070', '${tenantPublicId}', 'Hand Sanitizer 500ml', 'Dettol', 'OTHER', '500ml',
       'UNIT', NULL, '3401', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0070', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0070', '${tenantPublicId}', 'SKU-SEED0070', 'SEED-BATCH', DATE '2027-12-31', 15000,
       10500, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0070', 'BATCH-SEED0070', 'COUNTER', 20, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0070', 'BATCH-SEED0070', 'COUNTER', 20
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 71. Face Mask Box (3-ply)
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0071', '${tenantPublicId}', 'Face Mask Box (3-ply)', 'Venus', 'OTHER', '50 pcs',
       'UNIT', NULL, '3005', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0071', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0071', '${tenantPublicId}', 'SKU-SEED0071', 'SEED-BATCH', DATE '2027-12-31', 25000,
       17500, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0071', 'BATCH-SEED0071', 'COUNTER', 15, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0071', 'BATCH-SEED0071', 'COUNTER', 15
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 72. Digital Thermometer
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0072', '${tenantPublicId}', 'Digital Thermometer', 'Omron', 'OTHER', '1 pc',
       'UNIT', NULL, '9018', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0072', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0072', '${tenantPublicId}', 'SKU-SEED0072', 'SEED-BATCH', DATE '2027-12-31', 15000,
       10500, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0072', 'BATCH-SEED0072', 'COUNTER', 10, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0072', 'BATCH-SEED0072', 'COUNTER', 10
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 73. Glucometer Strips (25s)
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0073', '${tenantPublicId}', 'Glucometer Strips (25s)', 'Accu-Chek', 'OTHER', '25 strips',
       'UNIT', NULL, '9018', 1200, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0073', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0073', '${tenantPublicId}', 'SKU-SEED0073', 'SEED-BATCH', DATE '2027-12-31', 45000,
       31499, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0073', 'BATCH-SEED0073', 'COUNTER', 10, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0073', 'BATCH-SEED0073', 'COUNTER', 10
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 74. Syringe 5ml
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0074', '${tenantPublicId}', 'Syringe 5ml', 'Dispovan', 'OTHER', '5ml',
       'UNIT', NULL, '9018', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0074', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0074', '${tenantPublicId}', 'SKU-SEED0074', 'SEED-BATCH', DATE '2027-12-31', 800,
       560, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0074', 'BATCH-SEED0074', 'COUNTER', 50, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0074', 'BATCH-SEED0074', 'COUNTER', 50
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;


-- 75. Surgical Gloves Box (M)
INSERT INTO ${tenantSchema}.medicine_sku
    (sku_public_id, tenant_public_id, brand_name, manufacturer, dosage_form, strength,
     base_unit, schedule_class, hsn_code, gst_rate_bp, reorder_level, reorder_qty, active)
SELECT 'SKU-SEED0075', '${tenantPublicId}', 'Surgical Gloves Box (M)', 'Sterimed', 'OTHER', '100 pcs',
       'UNIT', NULL, '3005', 1800, 20, 50, true
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id) DO NOTHING;

INSERT INTO ${tenantSchema}.sku_pack (sku_public_id, pack_name, units_in_pack, sellable, is_base, sort_order)
SELECT 'SKU-SEED0075', 'Unit', 1, true, true, 0
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, lower(pack_name)) DO NOTHING;

INSERT INTO ${tenantSchema}.batch
    (batch_public_id, tenant_public_id, sku_public_id, batch_no, expiry_date, mrp_paise,
     purchase_price_paise, supplier_public_id, batch_status)
SELECT 'BATCH-SEED0075', '${tenantPublicId}', 'SKU-SEED0075', 'SEED-BATCH', DATE '2027-12-31', 35000,
       24500, 'SUP-SEED01', 'ACTIVE'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (sku_public_id, upper(batch_no)) DO NOTHING;

-- Flyway records this migration as applied exactly once per schema, the
-- same guarantee every other versioned migration in this codebase relies
-- on, so the ledger append below needs no re-run guard beyond the
-- pharmacy-enabled gate above.
INSERT INTO ${tenantSchema}.stock_ledger
    (tenant_public_id, sku_public_id, batch_public_id, location_id, qty_delta, reason,
     ref_type, ref_id, actor, note)
SELECT '${tenantPublicId}', 'SKU-SEED0075', 'BATCH-SEED0075', 'COUNTER', 10, 'OPENING',
       'MIGRATION', 'V6_SEED', 'system_seed', 'Starter catalog opening stock'
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean;

INSERT INTO ${tenantSchema}.batch_balance (sku_public_id, batch_public_id, location_id, qty)
SELECT 'SKU-SEED0075', 'BATCH-SEED0075', 'COUNTER', 10
WHERE current_setting('sevacare.seed_pharmacy_enabled', true)::boolean
ON CONFLICT (batch_public_id, location_id) DO NOTHING;
