-- =============================================================
-- V8: Add appointments for Doctor Queue - Yesterday, Today, Tomorrow
-- Demonstrates the facet queue flows for the Doctor Overview
-- =============================================================

-- Insert appointments for Yesterday (T-1001, Doctor D-1001)
INSERT INTO tenant_t_1001.appointment (appointment_public_id, patient_public_id, doctor_public_id, appointment_slot, appointment_status, notes)
VALUES
    ('APT-YDAY-01', 'P-1002', 'D-1001', TO_CHAR(CURRENT_DATE - INTERVAL '1 day', 'YYYY-MM-DD') || ' 09:00', 'completed', 'Cardiac checkup - routine (completed)'),
    ('APT-YDAY-02', 'P-1003', 'D-1001', TO_CHAR(CURRENT_DATE - INTERVAL '1 day', 'YYYY-MM-DD') || ' 09:30', 'completed', 'Blood pressure management follow-up (completed)'),
    ('APT-YDAY-03', 'P-1004', 'D-1001', TO_CHAR(CURRENT_DATE - INTERVAL '1 day', 'YYYY-MM-DD') || ' 10:00', 'completed', 'Cholesterol screening (completed)')
ON CONFLICT (appointment_public_id) DO NOTHING;

-- Insert appointments for Today (T-1001, Doctor D-1001)
INSERT INTO tenant_t_1001.appointment (appointment_public_id, patient_public_id, doctor_public_id, appointment_slot, appointment_status, notes)
VALUES
    ('APT-TODAY-01', 'P-1002', 'D-1001', TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 10:00', 'upcoming', 'Headache analysis and treatment plan'),
    ('APT-TODAY-02', 'P-1003', 'D-1001', TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 10:30', 'upcoming', 'ECG and consultation'),
    ('APT-TODAY-03', 'P-1005', 'D-1001', TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 14:00', 'upcoming', 'Routine checkup - quarterly follow-up')
ON CONFLICT (appointment_public_id) DO NOTHING;

-- Insert appointments for Tomorrow (T-1001, Doctor D-1001)
INSERT INTO tenant_t_1001.appointment (appointment_public_id, patient_public_id, doctor_public_id, appointment_slot, appointment_status, notes)
VALUES
    ('APT-TMRW-01', 'P-1002', 'D-1001', TO_CHAR(CURRENT_DATE + INTERVAL '1 day', 'YYYY-MM-DD') || ' 09:00', 'upcoming', 'Advanced cardiac imaging'),
    ('APT-TMRW-02', 'P-1004', 'D-1001', TO_CHAR(CURRENT_DATE + INTERVAL '1 day', 'YYYY-MM-DD') || ' 11:00', 'upcoming', 'Medication adjustment consultation'),
    ('APT-TMRW-03', 'P-1005', 'D-1001', TO_CHAR(CURRENT_DATE + INTERVAL '1 day', 'YYYY-MM-DD') || ' 15:30', 'upcoming', 'Post-treatment review')
ON CONFLICT (appointment_public_id) DO NOTHING;

-- Also add some appointments for other doctors to show varied queue
INSERT INTO tenant_t_1001.appointment (appointment_public_id, patient_public_id, doctor_public_id, appointment_slot, appointment_status, notes)
VALUES
    -- Dr. Arjun Varma (D-1002) - Today
    ('APT-2001', 'P-1002', 'D-1002', TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 10:00', 'upcoming', 'Neurological assessment'),
    ('APT-2002', 'P-1003', 'D-1002', TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 11:00', 'upcoming', 'Migraine management follow-up'),
    
    -- Dr. Priya Sharma (D-1003) - Today
    ('APT-2003', 'P-1004', 'D-1003', TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 14:00', 'upcoming', 'Gynecological checkup'),
    
    -- Dr. Sanjay Patel (D-1004) - Tomorrow
    ('APT-2004', 'P-1005', 'D-1004', TO_CHAR(CURRENT_DATE + INTERVAL '1 day', 'YYYY-MM-DD') || ' 10:00', 'upcoming', 'Dermatology consultation'),
    
    -- Dr. Kavitha Nair (D-1005) - Yesterday
    ('APT-2005', 'P-1002', 'D-1005', TO_CHAR(CURRENT_DATE - INTERVAL '1 day', 'YYYY-MM-DD') || ' 16:00', 'completed', 'General health check (completed)')
ON CONFLICT (appointment_public_id) DO NOTHING;
