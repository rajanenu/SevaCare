-- =============================================================
-- V6: Seed realistic data for Tenant T-1001 (Aurora Multispeciality)
-- Full lifecycle data: doctors, patients, appointments, prescriptions,
-- doctor details, schedules — all wired for end-to-end flows.
-- =============================================================

-- Reset sequences to avoid collisions
SELECT setval('public.patient_public_id_seq', 1010, false);
SELECT setval('public.doctor_public_id_seq', 1010, false);
SELECT setval('public.admin_public_id_seq', 1005, false);

-- =================== DOCTORS (T-1001) ===================
INSERT INTO tenant_t_1001.doctor (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
VALUES
    ('D-1002', 'T-1001', 'Dr. Arjun Varma', 'Neurologist', 'Today · 4 slots left', '₹850', true),
    ('D-1003', 'T-1001', 'Dr. Priya Sharma', 'Gynecologist', 'Today · 3 slots left', '₹700', true),
    ('D-1004', 'T-1001', 'Dr. Sanjay Patel', 'Skin Specialist', 'Tomorrow · 5 slots left', '₹600', true),
    ('D-1005', 'T-1001', 'Dr. Kavitha Nair', 'General Physician', 'Today · Open', '₹400', true)
ON CONFLICT (doctor_public_id) DO NOTHING;

-- =================== DOCTOR DETAILS (T-1001) ===================
INSERT INTO tenant_t_1001.doctor_details (doctor_public_id, tenant_public_id, mobile_number, age, gender, license_number, experience_years, address, city, state)
VALUES
    ('D-1001', 'T-1001', '9100000001', 42, 'female', 'MCI-TS-10201', 18, '8-2-120, Road No 3, Banjara Hills', 'Hyderabad', 'Telangana'),
    ('D-1002', 'T-1001', '9100000002', 38, 'male', 'MCI-TS-10202', 14, 'Plot 45, Jubilee Hills', 'Hyderabad', 'Telangana'),
    ('D-1003', 'T-1001', '9100000003', 35, 'female', 'MCI-TS-10203', 10, '6-3-248, Somajiguda', 'Hyderabad', 'Telangana'),
    ('D-1004', 'T-1001', '9100000004', 45, 'male', 'MCI-TS-10204', 20, '1-8-303, Begumpet', 'Hyderabad', 'Telangana'),
    ('D-1005', 'T-1001', '9100000005', 50, 'female', 'MCI-TS-10205', 25, '3-6-790, Himayatnagar', 'Hyderabad', 'Telangana')
ON CONFLICT (doctor_public_id) DO NOTHING;

-- =================== DOCTOR SCHEDULES (T-1001) ===================
INSERT INTO tenant_t_1001.doctor_schedule (schedule_public_id, doctor_public_id, tenant_public_id, appointment_interval_minutes, lunch_break_start_time, lunch_break_end_time, max_appointments_per_day, working_days, clinic_start_time, clinic_end_time)
VALUES
    ('SCH-1001', 'D-1001', 'T-1001', 15, '13:00', '14:00', 20, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '09:00', '18:00'),
    ('SCH-1002', 'D-1002', 'T-1001', 20, '13:00', '14:00', 16, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY', '09:30', '17:30'),
    ('SCH-1003', 'D-1003', 'T-1001', 15, '13:00', '14:00', 18, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '10:00', '18:00'),
    ('SCH-1004', 'D-1004', 'T-1001', 20, '12:30', '13:30', 14, 'MONDAY,WEDNESDAY,FRIDAY,SATURDAY', '10:00', '17:00'),
    ('SCH-1005', 'D-1005', 'T-1001', 10, '13:00', '14:00', 30, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '08:00', '20:00')
ON CONFLICT (schedule_public_id) DO NOTHING;

-- =================== PATIENTS (T-1001) ===================
INSERT INTO tenant_t_1001.patient (patient_public_id, tenant_public_id, full_name, mobile_number, status)
VALUES
    ('P-1002', 'T-1001', 'Anjali Reddy', '9000000002', 'active'),
    ('P-1003', 'T-1001', 'Vikram Kumar', '9000000003', 'active'),
    ('P-1004', 'T-1001', 'Lakshmi Devi', '9000000004', 'active'),
    ('P-1005', 'T-1001', 'Suresh Babu', '9000000005', 'active')
ON CONFLICT (patient_public_id) DO NOTHING;

-- =================== APPOINTMENTS (T-1001) ===================
INSERT INTO tenant_t_1001.appointment (appointment_public_id, patient_public_id, doctor_public_id, appointment_slot, appointment_status, notes)
VALUES
    ('APT-1002', 'P-1002', 'D-1002', 'Today · 10:00 AM', 'upcoming', 'Headache and dizziness since 2 weeks'),
    ('APT-1003', 'P-1003', 'D-1001', 'Today · 11:30 AM', 'upcoming', 'Routine cardiac checkup'),
    ('APT-1004', 'P-1004', 'D-1003', 'Tomorrow · 10:00 AM', 'upcoming', 'Prenatal checkup - 2nd trimester'),
    ('APT-1005', 'P-1001', 'D-1004', '18 Mar · 03:00 PM', 'past', 'Skin rash treatment follow-up'),
    ('APT-1006', 'P-1005', 'D-1005', '15 Mar · 09:00 AM', 'past', 'General health assessment complete')
ON CONFLICT (appointment_public_id) DO NOTHING;

-- =================== PRESCRIPTIONS (T-1001) ===================
INSERT INTO tenant_t_1001.prescription (prescription_public_id, patient_public_id, doctor_public_id, doctor_name, issued_on, notes)
VALUES
    ('RX-1002', 'P-1001', 'D-1004', 'Dr. Sanjay Patel', '2026-03-18', 'Cetirizine 10mg once daily for 7 days, Calamine lotion for affected area'),
    ('RX-1003', 'P-1002', 'D-1002', 'Dr. Arjun Varma', '2026-03-15', 'Sumatriptan 50mg as needed for migraine, Avoid screen time post 8PM'),
    ('RX-1004', 'P-1005', 'D-1005', 'Dr. Kavitha Nair', '2026-03-15', 'Vitamin D3 60000IU weekly, Iron supplement once daily, Follow-up in 30 days')
ON CONFLICT (prescription_public_id) DO NOTHING;

-- =================== T-1002 (GreenLeaf) - Additional data ===================
INSERT INTO tenant_t_1002.doctor (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
VALUES
    ('D-1004', 'T-1002', 'Dr. Ramesh Gupta', 'General Physician', 'Today · Walk-in open', '₹300', true)
ON CONFLICT (doctor_public_id) DO NOTHING;

INSERT INTO tenant_t_1002.patient (patient_public_id, tenant_public_id, full_name, mobile_number, status)
VALUES
    ('P-1004', 'T-1002', 'Rahul Teja', '9000000006', 'active')
ON CONFLICT (patient_public_id) DO NOTHING;

INSERT INTO tenant_t_1002.doctor_details (doctor_public_id, tenant_public_id, mobile_number, age, gender, license_number, experience_years, address, city, state)
VALUES
    ('D-1003', 'T-1002', '9100000010', 33, 'female', 'MCI-AP-20201', 8, '4-1-100, Hanamkonda', 'Warangal', 'Telangana'),
    ('D-1004', 'T-1002', '9100000011', 55, 'male', 'MCI-AP-20202', 28, '2-5-60, Fort Road', 'Warangal', 'Telangana')
ON CONFLICT (doctor_public_id) DO NOTHING;

INSERT INTO tenant_t_1002.doctor_schedule (schedule_public_id, doctor_public_id, tenant_public_id, appointment_interval_minutes, lunch_break_start_time, lunch_break_end_time, max_appointments_per_day, working_days, clinic_start_time, clinic_end_time)
VALUES
    ('SCH-2001', 'D-1003', 'T-1002', 15, '13:00', '14:00', 20, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '09:00', '18:00'),
    ('SCH-2002', 'D-1004', 'T-1002', 15, '13:00', '14:00', 25, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '08:00', '20:00')
ON CONFLICT (schedule_public_id) DO NOTHING;
