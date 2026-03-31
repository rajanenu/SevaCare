-- =============================================================
-- V10: Clean up legacy appointment seed data
-- Remove old appointments with non-standard slot formats
-- Keep only V8 appointments which use correct yyyy-MM-dd HH:mm format
-- =============================================================

-- Delete legacy appointments with non-standard slot formats (from V1 and V6)
DELETE FROM tenant_t_1001.appointment
WHERE appointment_slot NOT SIMILAR TO '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}';

DELETE FROM tenant_t_1002.appointment
WHERE appointment_slot NOT SIMILAR TO '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}';
