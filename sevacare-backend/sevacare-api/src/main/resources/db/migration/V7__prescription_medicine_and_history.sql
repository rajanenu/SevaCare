-- Enhance prescription table with additional fields
ALTER TABLE tenant_t_1001.prescription ADD COLUMN IF NOT EXISTS appointment_public_id VARCHAR(16);
ALTER TABLE tenant_t_1001.prescription ADD COLUMN IF NOT EXISTS valid_until DATE;
ALTER TABLE tenant_t_1001.prescription ADD COLUMN IF NOT EXISTS file_url VARCHAR(500);
ALTER TABLE tenant_t_1001.prescription ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE tenant_t_1001.prescription ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tenant_t_1001.prescription ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

ALTER TABLE tenant_t_1002.prescription ADD COLUMN IF NOT EXISTS appointment_public_id VARCHAR(16);
ALTER TABLE tenant_t_1002.prescription ADD COLUMN IF NOT EXISTS valid_until DATE;
ALTER TABLE tenant_t_1002.prescription ADD COLUMN IF NOT EXISTS file_url VARCHAR(500);
ALTER TABLE tenant_t_1002.prescription ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'active';
ALTER TABLE tenant_t_1002.prescription ADD COLUMN IF NOT EXISTS created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE tenant_t_1002.prescription ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Create prescription_medicine table for tenant_t_1001
CREATE TABLE IF NOT EXISTS tenant_t_1001.prescription_medicine (
    id SERIAL PRIMARY KEY,
    prescription_public_id VARCHAR(16) NOT NULL,
    medicine_name VARCHAR(255) NOT NULL,
    strength VARCHAR(100),
    frequency VARCHAR(255) NOT NULL,
    duration VARCHAR(100),
    instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (prescription_public_id) REFERENCES tenant_t_1001.prescription(prescription_public_id) ON DELETE CASCADE
);

-- Create prescription_medicine table for tenant_t_1002
CREATE TABLE IF NOT EXISTS tenant_t_1002.prescription_medicine (
    id SERIAL PRIMARY KEY,
    prescription_public_id VARCHAR(16) NOT NULL,
    medicine_name VARCHAR(255) NOT NULL,
    strength VARCHAR(100),
    frequency VARCHAR(255) NOT NULL,
    duration VARCHAR(100),
    instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (prescription_public_id) REFERENCES tenant_t_1002.prescription(prescription_public_id) ON DELETE CASCADE
);

-- Create medical_history table for tenant_t_1001
CREATE TABLE IF NOT EXISTS tenant_t_1001.medical_history (
    id SERIAL PRIMARY KEY,
    patient_public_id VARCHAR(16) NOT NULL,
    record_type VARCHAR(50),
    record_value VARCHAR(255) NOT NULL,
    notes TEXT,
    record_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_public_id) REFERENCES tenant_t_1001.patient(patient_public_id) ON DELETE CASCADE
);

-- Create medical_history table for tenant_t_1002
CREATE TABLE IF NOT EXISTS tenant_t_1002.medical_history (
    id SERIAL PRIMARY KEY,
    patient_public_id VARCHAR(16) NOT NULL,
    record_type VARCHAR(50),
    record_value VARCHAR(255) NOT NULL,
    notes TEXT,
    record_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (patient_public_id) REFERENCES tenant_t_1002.patient(patient_public_id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_prescription_medicine_rx ON tenant_t_1001.prescription_medicine(prescription_public_id);
CREATE INDEX IF NOT EXISTS idx_prescription_medicine_rx_2 ON tenant_t_1002.prescription_medicine(prescription_public_id);
CREATE INDEX IF NOT EXISTS idx_medical_history_patient ON tenant_t_1001.medical_history(patient_public_id);
CREATE INDEX IF NOT EXISTS idx_medical_history_patient_2 ON tenant_t_1002.medical_history(patient_public_id);

-- Seed test data for prescriptions with medicines
INSERT INTO tenant_t_1001.prescription_medicine (prescription_public_id, medicine_name, strength, frequency, duration, instructions)
VALUES 
    ('RX-1001', 'Amlodipine', '5 mg', 'Once daily', '30 days', 'Take after breakfast'),
    ('RX-1001', 'Lisinopril', '10 mg', 'Once daily', '30 days', 'Take in morning'),
    ('RX-1001', 'Aspirin', '75 mg', 'Once daily', '30 days', 'Take with food')
ON CONFLICT DO NOTHING;

-- Seed test data for medical history
INSERT INTO tenant_t_1001.medical_history (patient_public_id, record_type, record_value, notes, record_date)
VALUES 
    ('P-1001', 'allergy', 'Penicillin', 'Severe - causes rash', '2026-01-15'),
    ('P-1001', 'allergy', 'NSAIDs', 'Moderate - causes GI upset', '2026-02-20'),
    ('P-1001', 'condition', 'Hypertension', 'Diagnosed 5 years ago', '2021-03-10'),
    ('P-1001', 'condition', 'Type 2 Diabetes', 'Well controlled with medication', '2022-06-15'),
    ('P-1001', 'record', 'Last Blood Work', 'Fasting: 125 mg/dL, HbA1c: 6.8%', '2026-02-28'),
    ('P-1001', 'follow_up', 'Cardiologist Follow-up Required', 'Follow up in 3 months', '2026-04-12')
ON CONFLICT DO NOTHING;
