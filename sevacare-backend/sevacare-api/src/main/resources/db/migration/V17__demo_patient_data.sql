-- =============================================================
-- V17: Seed demo data into tenant_t_1013 (T-1013 "Lakshmi Kishore").
--      T-1013 is a RUNTIME-onboarded tenant, so on a fresh database its
--      schema does not exist yet — this whole block is guarded by a schema
--      existence check (same pattern as V20/V22) so a clean DB migrates
--      without error. Fully seeded demo data for a clean DB lives in T-1001.
-- =============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'tenant_t_1013') THEN

    -- 1. Add blood_group column (safe, nullable)
    ALTER TABLE tenant_t_1013.patient ADD COLUMN IF NOT EXISTS blood_group VARCHAR(5);

    -- 2. Enrich existing demo patient P-1016
    UPDATE tenant_t_1013.patient
    SET full_name     = 'Rajasekhar Reddy',
        email         = 'demo@sevacare.in',
        gender        = 'male',
        age           = 32,
        blood_group   = 'B+',
        status        = 'active'
    WHERE patient_public_id = 'P-1016';

    -- 3. Add more specialist doctors to T-1013
    INSERT INTO tenant_t_1013.doctor
        (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
    VALUES
        ('D-1002', 'T-1013', 'Dr. Ananya Krishnan',  'Cardiologist',       'Today · 4 slots left', '₹900',  true),
        ('D-1003', 'T-1013', 'Dr. Arjun Varma',      'Neurologist',        'Today · 3 slots left', '₹850',  true),
        ('D-1004', 'T-1013', 'Dr. Priya Sharma',     'Gynecologist',       'Today · 2 slots left', '₹700',  true),
        ('D-1005', 'T-1013', 'Dr. Sanjay Patel',     'Skin Specialist',    'Today · Open',         '₹600',  true),
        ('D-1006', 'T-1013', 'Dr. Kavitha Nair',     'General Physician',  'Today · Open',         '₹400',  true)
    ON CONFLICT (doctor_public_id) DO UPDATE
        SET full_name    = EXCLUDED.full_name,
            specialty    = EXCLUDED.specialty,
            availability = EXCLUDED.availability,
            fee          = EXCLUDED.fee,
            active       = EXCLUDED.active;

    -- 4. Today's upcoming appointments for P-1016
    INSERT INTO tenant_t_1013.appointment
        (appointment_public_id, tenant_public_id, patient_public_id, doctor_public_id,
         appointment_slot, appointment_status, notes)
    VALUES
        ('APT-DEMO-TODAY-01', 'T-1013', 'P-1016', 'D-1006',
         TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 10:00', 'upcoming',
         'Routine general health checkup'),
        ('APT-DEMO-TODAY-02', 'T-1013', 'P-1016', 'D-1002',
         TO_CHAR(CURRENT_DATE, 'YYYY-MM-DD') || ' 14:30', 'upcoming',
         'Cardiac evaluation follow-up')
    ON CONFLICT (appointment_public_id) DO NOTHING;

    -- 5. Past appointments for medical history
    INSERT INTO tenant_t_1013.appointment
        (appointment_public_id, tenant_public_id, patient_public_id, doctor_public_id,
         appointment_slot, appointment_status, notes)
    VALUES
        ('APT-DEMO-PAST-01', 'T-1013', 'P-1016', 'D-1001',
         TO_CHAR(CURRENT_DATE - INTERVAL '7 days', 'YYYY-MM-DD') || ' 11:00', 'completed',
         'General consultation — all clear'),
        ('APT-DEMO-PAST-02', 'T-1013', 'P-1016', 'D-1003',
         TO_CHAR(CURRENT_DATE - INTERVAL '14 days', 'YYYY-MM-DD') || ' 09:30', 'completed',
         'Neurology follow-up — responded well to treatment')
    ON CONFLICT (appointment_public_id) DO NOTHING;

    -- 6. Prescription for P-1016
    INSERT INTO tenant_t_1013.prescription
        (prescription_public_id, tenant_public_id, patient_public_id, doctor_public_id,
         doctor_name, prescription_date, notes)
    VALUES
        ('RX-DEMO-001', 'T-1013', 'P-1016', 'D-1001',
         'Rajasekhar',
         (CURRENT_DATE - INTERVAL '7 days')::date,
         'Paracetamol 500mg twice daily, Vitamin D3 60K weekly for 8 weeks')
    ON CONFLICT (prescription_public_id) DO NOTHING;

  END IF;
END $$;
