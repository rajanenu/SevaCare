CREATE SEQUENCE IF NOT EXISTS public.tenant_public_id_seq START WITH 1005;
CREATE SEQUENCE IF NOT EXISTS public.patient_public_id_seq START WITH 1005;
CREATE SEQUENCE IF NOT EXISTS public.doctor_public_id_seq START WITH 1005;
CREATE SEQUENCE IF NOT EXISTS public.admin_public_id_seq START WITH 1002;
CREATE SEQUENCE IF NOT EXISTS public.onboarding_request_public_id_seq START WITH 1001;

CREATE TABLE IF NOT EXISTS public.tenant_registry (
    tenant_public_id VARCHAR(16) PRIMARY KEY,
    tenant_name VARCHAR(120) NOT NULL,
    tenant_theme_key VARCHAR(32) NOT NULL,
    tenant_schema_name VARCHAR(63) NOT NULL UNIQUE,
    tenant_status VARCHAR(24) NOT NULL DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS public.tenant_onboarding_request (
    request_public_id VARCHAR(24) PRIMARY KEY,
    hospital_name VARCHAR(160) NOT NULL,
    city VARCHAR(120) NOT NULL,
    address VARCHAR(300) NOT NULL DEFAULT '',
    country VARCHAR(120) NOT NULL DEFAULT 'India',
    contact_name VARCHAR(120) NOT NULL,
    contact_mobile VARCHAR(24) NOT NULL,
    contact_email VARCHAR(160) NOT NULL,
    facility_type VARCHAR(32) NOT NULL,
    request_status VARCHAR(24) NOT NULL DEFAULT 'submitted',
    requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO public.tenant_registry (tenant_public_id, tenant_name, tenant_theme_key, tenant_schema_name, tenant_status)
VALUES
    ('T-1001', 'Aurora Multispeciality', 'premium', 'tenant_t_1001', 'active'),
    ('T-1002', 'GreenLeaf Family Clinic', 'clinic', 'tenant_t_1002', 'active')
ON CONFLICT (tenant_public_id) DO NOTHING;

CREATE SCHEMA IF NOT EXISTS tenant_t_1001;
CREATE SCHEMA IF NOT EXISTS tenant_t_1002;

CREATE TABLE IF NOT EXISTS tenant_t_1001.patient (
    patient_public_id VARCHAR(16) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    mobile_number VARCHAR(24) NOT NULL,
    status VARCHAR(24) NOT NULL
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.patient (
    LIKE tenant_t_1001.patient INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS tenant_t_1001.doctor (
    doctor_public_id VARCHAR(16) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    specialty VARCHAR(120) NOT NULL,
    availability VARCHAR(120) NOT NULL,
    fee VARCHAR(32) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.doctor (
    LIKE tenant_t_1001.doctor INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS tenant_t_1001.doctor_details (
    doctor_public_id VARCHAR(16) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    mobile_number VARCHAR(24) NOT NULL,
    age INT NOT NULL,
    gender VARCHAR(24) NOT NULL,
    license_number VARCHAR(60) NOT NULL UNIQUE,
    experience_years INT NOT NULL,
    address VARCHAR(300) NOT NULL,
    city VARCHAR(120) NOT NULL,
    state VARCHAR(120) NOT NULL,
    license_photo_url VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_public_id) REFERENCES tenant_t_1001.doctor(doctor_public_id)
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.doctor_details (
    LIKE tenant_t_1001.doctor_details INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS tenant_t_1001.doctor_schedule (
    schedule_public_id VARCHAR(16) PRIMARY KEY,
    doctor_public_id VARCHAR(16) NOT NULL,
    tenant_public_id VARCHAR(16) NOT NULL,
    appointment_interval_minutes INT NOT NULL DEFAULT 15,
    lunch_break_start_time VARCHAR(8) NOT NULL,
    lunch_break_end_time VARCHAR(8) NOT NULL,
    max_appointments_per_day INT NOT NULL DEFAULT 8,
    working_days VARCHAR(100) NOT NULL DEFAULT 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY',
    clinic_start_time VARCHAR(8) NOT NULL DEFAULT '09:00',
    clinic_end_time VARCHAR(8) NOT NULL DEFAULT '18:00',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_public_id) REFERENCES tenant_t_1001.doctor(doctor_public_id)
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.doctor_schedule (
    LIKE tenant_t_1001.doctor_schedule INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS tenant_t_1001.doctor_license_metadata (
    license_id VARCHAR(16) PRIMARY KEY,
    doctor_public_id VARCHAR(16) NOT NULL,
    tenant_public_id VARCHAR(16) NOT NULL,
    license_file_name VARCHAR(200) NOT NULL,
    license_file_size BIGINT NOT NULL,
    license_upload_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (doctor_public_id) REFERENCES tenant_t_1001.doctor(doctor_public_id)
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.doctor_license_metadata (
    LIKE tenant_t_1001.doctor_license_metadata INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS tenant_t_1001.admin_user (
    admin_public_id VARCHAR(16) PRIMARY KEY,
    tenant_public_id VARCHAR(16) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.admin_user (
    LIKE tenant_t_1001.admin_user INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS tenant_t_1001.appointment (
    appointment_public_id VARCHAR(16) PRIMARY KEY,
    patient_public_id VARCHAR(16) NOT NULL,
    doctor_public_id VARCHAR(16) NOT NULL,
    appointment_slot VARCHAR(80) NOT NULL,
    appointment_status VARCHAR(24) NOT NULL,
    notes VARCHAR(300) NOT NULL
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.appointment (
    LIKE tenant_t_1001.appointment INCLUDING ALL
);

CREATE TABLE IF NOT EXISTS tenant_t_1001.prescription (
    prescription_public_id VARCHAR(16) PRIMARY KEY,
    patient_public_id VARCHAR(16) NOT NULL,
    doctor_public_id VARCHAR(16) NOT NULL,
    doctor_name VARCHAR(120) NOT NULL,
    issued_on VARCHAR(20) NOT NULL,
    notes VARCHAR(2000) NOT NULL
);
CREATE TABLE IF NOT EXISTS tenant_t_1002.prescription (
    LIKE tenant_t_1001.prescription INCLUDING ALL
);

INSERT INTO tenant_t_1001.admin_user (admin_public_id, tenant_public_id, full_name, active)
VALUES ('A-1001', 'T-1001', 'Admin Aurora', true)
ON CONFLICT (admin_public_id) DO NOTHING;

INSERT INTO tenant_t_1002.admin_user (admin_public_id, tenant_public_id, full_name, active)
VALUES ('A-1002', 'T-1002', 'Admin GreenLeaf', true)
ON CONFLICT (admin_public_id) DO NOTHING;

INSERT INTO tenant_t_1001.patient (patient_public_id, tenant_public_id, full_name, mobile_number, status)
VALUES ('P-1001', 'T-1001', 'Rohan Sharma', '9000000001', 'active')
ON CONFLICT (patient_public_id) DO NOTHING;

INSERT INTO tenant_t_1002.patient (patient_public_id, tenant_public_id, full_name, mobile_number, status)
VALUES ('P-1003', 'T-1002', 'Sita Naik', '9000000003', 'active')
ON CONFLICT (patient_public_id) DO NOTHING;

INSERT INTO tenant_t_1001.doctor (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
VALUES ('D-1001', 'T-1001', 'Dr. Meera Rao', 'Cardiologist', 'Today · 6 slots left', '₹900', true)
ON CONFLICT (doctor_public_id) DO NOTHING;

INSERT INTO tenant_t_1002.doctor (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
VALUES ('D-1003', 'T-1002', 'Dr. Kavya Reddy', 'Family Medicine', 'Today · Walk-in open', '₹350', true)
ON CONFLICT (doctor_public_id) DO NOTHING;

INSERT INTO tenant_t_1001.appointment (appointment_public_id, patient_public_id, doctor_public_id, appointment_slot, appointment_status, notes)
VALUES ('APT-1001', 'P-1001', 'D-1001', 'Today · 4:30 PM', 'upcoming', 'Bring previous ECG reports')
ON CONFLICT (appointment_public_id) DO NOTHING;

INSERT INTO tenant_t_1001.prescription (prescription_public_id, patient_public_id, doctor_public_id, doctor_name, issued_on, notes)
VALUES ('RX-1001', 'P-1001', 'D-1001', 'Dr. Meera Rao', '2026-03-12', 'Amlodipine 5 mg once daily after breakfast')
ON CONFLICT (prescription_public_id) DO NOTHING;
