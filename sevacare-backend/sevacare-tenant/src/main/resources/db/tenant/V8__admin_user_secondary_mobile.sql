-- =============================================================
-- V8: An optional secondary contact number for admin/staff.
--
-- mobile_number stays the login identity (untouched by profile saves,
-- enforced in AdminDomainService.applyAdminUserUpdates); this is a second,
-- freely editable number for someone who wants to list an alternate contact.
-- =============================================================

ALTER TABLE ${tenantSchema}.admin_user
    ADD COLUMN IF NOT EXISTS secondary_mobile VARCHAR(24);
