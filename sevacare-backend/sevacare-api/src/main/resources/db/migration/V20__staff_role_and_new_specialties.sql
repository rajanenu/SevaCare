-- =============================================================
-- V20: IP-Staff role support + Dental/Pediatrics doctors
-- user_type column is handled dynamically by TenantAdminSchemaInitializer.
-- Doctor seeding uses conditional blocks to tolerate missing tenant schemas.
-- =============================================================

DO $$
BEGIN
  -- Seed Dental and Pediatrics doctors for T-1013 (Lakshmi Kishore Hospital)
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'tenant_t_1013') THEN

    INSERT INTO tenant_t_1013.doctor (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
    VALUES
      ('D-1007', 'T-1013', 'Dr. Suresh Dental',    'Dental',     'Today · 4 slots left', '₹500', true),
      ('D-1008', 'T-1013', 'Dr. Meena Pediatrics', 'Pediatrics', 'Today · 5 slots left', '₹450', true)
    ON CONFLICT (doctor_public_id) DO NOTHING;

    INSERT INTO tenant_t_1013.doctor_details (doctor_public_id, tenant_public_id, mobile_number, age, gender, license_number, experience_years, address, city, state)
    VALUES
      ('D-1007', 'T-1013', '9100001007', 40, 'male',   'MCI-TS-30701', 15, '7-1-80, Ameerpet', 'Hyderabad', 'Telangana'),
      ('D-1008', 'T-1013', '9100001008', 36, 'female', 'MCI-TS-30801', 11, '5-4-25, Abids',    'Hyderabad', 'Telangana')
    ON CONFLICT (doctor_public_id) DO NOTHING;

    INSERT INTO tenant_t_1013.doctor_schedule (schedule_public_id, doctor_public_id, tenant_public_id, appointment_interval_minutes, lunch_break_start_time, lunch_break_end_time, max_appointments_per_day, working_days, clinic_start_time, clinic_end_time)
    VALUES
      ('SCH-T1013-007', 'D-1007', 'T-1013', 15, '13:00', '14:00', 20, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '09:00', '18:00'),
      ('SCH-T1013-008', 'D-1008', 'T-1013', 15, '13:00', '14:00', 20, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '09:00', '18:00')
    ON CONFLICT (schedule_public_id) DO NOTHING;

  END IF;

  -- Seed Dental and Pediatrics doctors for T-1001 (Aurora Multispeciality)
  IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'tenant_t_1001') THEN

    INSERT INTO tenant_t_1001.doctor (doctor_public_id, tenant_public_id, full_name, specialty, availability, fee, active)
    VALUES
      ('D-1006', 'T-1001', 'Dr. Ravi Dental',       'Dental',     'Today · 3 slots left', '₹550', true),
      ('D-1007', 'T-1001', 'Dr. Sunita Pediatrics', 'Pediatrics', 'Today · 4 slots left', '₹480', true)
    ON CONFLICT (doctor_public_id) DO NOTHING;

    INSERT INTO tenant_t_1001.doctor_details (doctor_public_id, tenant_public_id, mobile_number, age, gender, license_number, experience_years, address, city, state)
    VALUES
      ('D-1006', 'T-1001', '9100000006', 38, 'male',   'MCI-TS-10601', 13, '10-3-45, Jubilee Hills', 'Hyderabad', 'Telangana'),
      ('D-1007', 'T-1001', '9100000007', 32, 'female', 'MCI-TS-10701',  8, '2-7-120, Banjara Hills', 'Hyderabad', 'Telangana')
    ON CONFLICT (doctor_public_id) DO NOTHING;

    INSERT INTO tenant_t_1001.doctor_schedule (schedule_public_id, doctor_public_id, tenant_public_id, appointment_interval_minutes, lunch_break_start_time, lunch_break_end_time, max_appointments_per_day, working_days, clinic_start_time, clinic_end_time)
    VALUES
      ('SCH-1006', 'D-1006', 'T-1001', 15, '13:00', '14:00', 20, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '09:00', '18:00'),
      ('SCH-1007', 'D-1007', 'T-1001', 15, '13:00', '14:00', 20, 'MONDAY,TUESDAY,WEDNESDAY,THURSDAY,FRIDAY,SATURDAY', '09:00', '18:00')
    ON CONFLICT (schedule_public_id) DO NOTHING;

  END IF;
END $$;
