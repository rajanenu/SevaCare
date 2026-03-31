-- =============================================================
-- V5: Create indexes for all tenant and public tables
-- Covers foreign keys, lookup columns, status fields, and
-- common query patterns for optimal performance.
-- =============================================================

-- ===================== PUBLIC SCHEMA INDEXES =====================

-- tenant_registry
CREATE INDEX IF NOT EXISTS idx_tenant_registry_status
    ON public.tenant_registry (tenant_status);

CREATE INDEX IF NOT EXISTS idx_tenant_registry_schema
    ON public.tenant_registry (tenant_schema_name);

-- tenant_onboarding_request
CREATE INDEX IF NOT EXISTS idx_onboarding_request_status
    ON public.tenant_onboarding_request (request_status);

CREATE INDEX IF NOT EXISTS idx_onboarding_request_city
    ON public.tenant_onboarding_request (city);

CREATE INDEX IF NOT EXISTS idx_onboarding_request_contact_mobile
    ON public.tenant_onboarding_request (contact_mobile);

-- specialization_master
CREATE INDEX IF NOT EXISTS idx_specialization_master_active
    ON public.specialization_master (active, display_order);

-- city_master
CREATE INDEX IF NOT EXISTS idx_city_master_active
    ON public.city_master (active, display_order);


-- ===================== TENANT T-1001 INDEXES =====================

-- patient
CREATE INDEX IF NOT EXISTS idx_t1001_patient_tenant
    ON tenant_t_1001.patient (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_patient_mobile
    ON tenant_t_1001.patient (mobile_number);

CREATE INDEX IF NOT EXISTS idx_t1001_patient_status
    ON tenant_t_1001.patient (status);

-- doctor
CREATE INDEX IF NOT EXISTS idx_t1001_doctor_tenant
    ON tenant_t_1001.doctor (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_doctor_specialty
    ON tenant_t_1001.doctor (specialty);

CREATE INDEX IF NOT EXISTS idx_t1001_doctor_active
    ON tenant_t_1001.doctor (active);

CREATE INDEX IF NOT EXISTS idx_t1001_doctor_tenant_active
    ON tenant_t_1001.doctor (tenant_public_id, active);

-- doctor_details
CREATE INDEX IF NOT EXISTS idx_t1001_doctor_details_tenant
    ON tenant_t_1001.doctor_details (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_doctor_details_city
    ON tenant_t_1001.doctor_details (city);

-- doctor_schedule
CREATE INDEX IF NOT EXISTS idx_t1001_doctor_schedule_doctor
    ON tenant_t_1001.doctor_schedule (doctor_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_doctor_schedule_tenant
    ON tenant_t_1001.doctor_schedule (tenant_public_id);

-- doctor_license_metadata
CREATE INDEX IF NOT EXISTS idx_t1001_license_meta_doctor
    ON tenant_t_1001.doctor_license_metadata (doctor_public_id);

-- admin_user
CREATE INDEX IF NOT EXISTS idx_t1001_admin_tenant
    ON tenant_t_1001.admin_user (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_admin_active
    ON tenant_t_1001.admin_user (active);

-- appointment
CREATE INDEX IF NOT EXISTS idx_t1001_appt_patient
    ON tenant_t_1001.appointment (patient_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_appt_doctor
    ON tenant_t_1001.appointment (doctor_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_appt_status
    ON tenant_t_1001.appointment (appointment_status);

CREATE INDEX IF NOT EXISTS idx_t1001_appt_slot
    ON tenant_t_1001.appointment (appointment_slot);

CREATE INDEX IF NOT EXISTS idx_t1001_appt_doctor_status
    ON tenant_t_1001.appointment (doctor_public_id, appointment_status);

-- prescription
CREATE INDEX IF NOT EXISTS idx_t1001_rx_patient
    ON tenant_t_1001.prescription (patient_public_id);

CREATE INDEX IF NOT EXISTS idx_t1001_rx_doctor
    ON tenant_t_1001.prescription (doctor_public_id);


-- ===================== TENANT T-1002 INDEXES =====================

-- patient
CREATE INDEX IF NOT EXISTS idx_t1002_patient_tenant
    ON tenant_t_1002.patient (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_patient_mobile
    ON tenant_t_1002.patient (mobile_number);

CREATE INDEX IF NOT EXISTS idx_t1002_patient_status
    ON tenant_t_1002.patient (status);

-- doctor
CREATE INDEX IF NOT EXISTS idx_t1002_doctor_tenant
    ON tenant_t_1002.doctor (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_doctor_specialty
    ON tenant_t_1002.doctor (specialty);

CREATE INDEX IF NOT EXISTS idx_t1002_doctor_active
    ON tenant_t_1002.doctor (active);

CREATE INDEX IF NOT EXISTS idx_t1002_doctor_tenant_active
    ON tenant_t_1002.doctor (tenant_public_id, active);

-- doctor_details
CREATE INDEX IF NOT EXISTS idx_t1002_doctor_details_tenant
    ON tenant_t_1002.doctor_details (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_doctor_details_city
    ON tenant_t_1002.doctor_details (city);

-- doctor_schedule
CREATE INDEX IF NOT EXISTS idx_t1002_doctor_schedule_doctor
    ON tenant_t_1002.doctor_schedule (doctor_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_doctor_schedule_tenant
    ON tenant_t_1002.doctor_schedule (tenant_public_id);

-- doctor_license_metadata
CREATE INDEX IF NOT EXISTS idx_t1002_license_meta_doctor
    ON tenant_t_1002.doctor_license_metadata (doctor_public_id);

-- admin_user
CREATE INDEX IF NOT EXISTS idx_t1002_admin_tenant
    ON tenant_t_1002.admin_user (tenant_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_admin_active
    ON tenant_t_1002.admin_user (active);

-- appointment
CREATE INDEX IF NOT EXISTS idx_t1002_appt_patient
    ON tenant_t_1002.appointment (patient_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_appt_doctor
    ON tenant_t_1002.appointment (doctor_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_appt_status
    ON tenant_t_1002.appointment (appointment_status);

CREATE INDEX IF NOT EXISTS idx_t1002_appt_slot
    ON tenant_t_1002.appointment (appointment_slot);

CREATE INDEX IF NOT EXISTS idx_t1002_appt_doctor_status
    ON tenant_t_1002.appointment (doctor_public_id, appointment_status);

-- prescription
CREATE INDEX IF NOT EXISTS idx_t1002_rx_patient
    ON tenant_t_1002.prescription (patient_public_id);

CREATE INDEX IF NOT EXISTS idx_t1002_rx_doctor
    ON tenant_t_1002.prescription (doctor_public_id);
