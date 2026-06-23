-- =============================================================
-- V15: Hospital Admin Enrollment & QR Code Support
-- =============================================================

-- 1. Hospital Admin Enrollment Table
CREATE TABLE IF NOT EXISTS public.hospital_admin_enrollment (
    admin_enrollment_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL UNIQUE,
    hospital_admin_mobile VARCHAR(24) NOT NULL UNIQUE,
    hospital_admin_name VARCHAR(160),
    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_hospital_admin_mobile 
    ON public.hospital_admin_enrollment (hospital_admin_mobile);
CREATE INDEX IF NOT EXISTS idx_hospital_admin_tenant 
    ON public.hospital_admin_enrollment (tenant_public_id);

-- 2. Hospital QR Code Storage
CREATE TABLE IF NOT EXISTS public.hospital_qrcode (
    qrcode_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    qrcode_uuid VARCHAR(36) NOT NULL UNIQUE,
    qrcode_url VARCHAR(1024),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_public_id) REFERENCES public.tenant_registry(tenant_public_id)
);

CREATE INDEX IF NOT EXISTS idx_hospital_qrcode_uuid 
    ON public.hospital_qrcode (qrcode_uuid);
CREATE INDEX IF NOT EXISTS idx_hospital_qrcode_tenant 
    ON public.hospital_qrcode (tenant_public_id);

-- 3. Doctor Onboarding/Enrollment in Hospital
CREATE TABLE IF NOT EXISTS public.doctor_hospital_enrollment (
    doctor_enrollment_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    doctor_mobile VARCHAR(24) NOT NULL,
    doctor_name VARCHAR(160) NOT NULL,
    specialty VARCHAR(120) NOT NULL,
    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active BOOLEAN NOT NULL DEFAULT true,
    UNIQUE(tenant_public_id, doctor_mobile),
    FOREIGN KEY (tenant_public_id) REFERENCES public.tenant_registry(tenant_public_id)
);

CREATE INDEX IF NOT EXISTS idx_doctor_enrollment_mobile 
    ON public.doctor_hospital_enrollment (doctor_mobile);
CREATE INDEX IF NOT EXISTS idx_doctor_enrollment_tenant 
    ON public.doctor_hospital_enrollment (tenant_public_id);

-- 4. Appointment Request (QR-based flow)
CREATE TABLE IF NOT EXISTS public.appointment_request (
    request_public_id VARCHAR(24) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    patient_mobile VARCHAR(24) NOT NULL,
    patient_name VARCHAR(160) NOT NULL,
    patient_age INT NOT NULL,
    symptoms VARCHAR(500) NOT NULL,
    doctor_public_id VARCHAR(16) NOT NULL,
    specialty VARCHAR(120) NOT NULL,
    preferred_date DATE NOT NULL,
    request_status VARCHAR(24) NOT NULL DEFAULT 'pending',
    assigned_slot VARCHAR(50),
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (tenant_public_id) REFERENCES public.tenant_registry(tenant_public_id)
);

CREATE INDEX IF NOT EXISTS idx_appointment_request_tenant 
    ON public.appointment_request (tenant_public_id);
CREATE INDEX IF NOT EXISTS idx_appointment_request_status 
    ON public.appointment_request (request_status);
CREATE INDEX IF NOT EXISTS idx_appointment_request_doctor 
    ON public.appointment_request (doctor_public_id);
CREATE INDEX IF NOT EXISTS idx_appointment_request_patient_mobile 
    ON public.appointment_request (patient_mobile);

-- Seed hospital admin for T-2001 (SevaCare Local Hospital)
INSERT INTO public.tenant_registry (tenant_public_id, tenant_name, tenant_theme_key, tenant_schema_name, tenant_status)
VALUES ('T-2001', 'SevaCare Local Hospital', 'premium', 'tenant_t_2001', 'active')
ON CONFLICT (tenant_public_id) DO NOTHING;

INSERT INTO public.hospital_admin_enrollment (admin_enrollment_public_id, tenant_public_id, hospital_admin_mobile, hospital_admin_name, active)
VALUES ('HA-T2001-001', 'T-2001', '9000000003', 'Hospital Admin', true)
ON CONFLICT (admin_enrollment_public_id) DO NOTHING;

-- Seed a QR code for T-2001
INSERT INTO public.hospital_qrcode (qrcode_public_id, tenant_public_id, qrcode_uuid)
VALUES ('QR-T2001-001', 'T-2001', '550e8400-e29b-41d4-a716-446655440000')
ON CONFLICT (qrcode_public_id) DO NOTHING;
