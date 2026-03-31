-- Add tenant_public_id to tenant-scoped transactional tables for explicit API-level tenant safety.

-- tenant_t_1001
ALTER TABLE tenant_t_1001.appointment ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(16);
ALTER TABLE tenant_t_1001.prescription ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(16);
ALTER TABLE tenant_t_1001.medical_history ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(16);

UPDATE tenant_t_1001.appointment SET tenant_public_id = 'T-1001' WHERE tenant_public_id IS NULL;
UPDATE tenant_t_1001.prescription SET tenant_public_id = 'T-1001' WHERE tenant_public_id IS NULL;
UPDATE tenant_t_1001.medical_history SET tenant_public_id = 'T-1001' WHERE tenant_public_id IS NULL;

ALTER TABLE tenant_t_1001.appointment ALTER COLUMN tenant_public_id SET NOT NULL;
ALTER TABLE tenant_t_1001.prescription ALTER COLUMN tenant_public_id SET NOT NULL;
ALTER TABLE tenant_t_1001.medical_history ALTER COLUMN tenant_public_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_appointment_tenant_status_t1001 ON tenant_t_1001.appointment(tenant_public_id, appointment_status);
CREATE INDEX IF NOT EXISTS idx_appointment_tenant_doctor_t1001 ON tenant_t_1001.appointment(tenant_public_id, doctor_public_id);
CREATE INDEX IF NOT EXISTS idx_prescription_tenant_patient_t1001 ON tenant_t_1001.prescription(tenant_public_id, patient_public_id);
CREATE INDEX IF NOT EXISTS idx_prescription_tenant_doctor_t1001 ON tenant_t_1001.prescription(tenant_public_id, doctor_public_id);
CREATE INDEX IF NOT EXISTS idx_medical_history_tenant_patient_t1001 ON tenant_t_1001.medical_history(tenant_public_id, patient_public_id);

-- tenant_t_1002
ALTER TABLE tenant_t_1002.appointment ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(16);
ALTER TABLE tenant_t_1002.prescription ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(16);
ALTER TABLE tenant_t_1002.medical_history ADD COLUMN IF NOT EXISTS tenant_public_id VARCHAR(16);

UPDATE tenant_t_1002.appointment SET tenant_public_id = 'T-1002' WHERE tenant_public_id IS NULL;
UPDATE tenant_t_1002.prescription SET tenant_public_id = 'T-1002' WHERE tenant_public_id IS NULL;
UPDATE tenant_t_1002.medical_history SET tenant_public_id = 'T-1002' WHERE tenant_public_id IS NULL;

ALTER TABLE tenant_t_1002.appointment ALTER COLUMN tenant_public_id SET NOT NULL;
ALTER TABLE tenant_t_1002.prescription ALTER COLUMN tenant_public_id SET NOT NULL;
ALTER TABLE tenant_t_1002.medical_history ALTER COLUMN tenant_public_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_appointment_tenant_status_t1002 ON tenant_t_1002.appointment(tenant_public_id, appointment_status);
CREATE INDEX IF NOT EXISTS idx_appointment_tenant_doctor_t1002 ON tenant_t_1002.appointment(tenant_public_id, doctor_public_id);
CREATE INDEX IF NOT EXISTS idx_prescription_tenant_patient_t1002 ON tenant_t_1002.prescription(tenant_public_id, patient_public_id);
CREATE INDEX IF NOT EXISTS idx_prescription_tenant_doctor_t1002 ON tenant_t_1002.prescription(tenant_public_id, doctor_public_id);
CREATE INDEX IF NOT EXISTS idx_medical_history_tenant_patient_t1002 ON tenant_t_1002.medical_history(tenant_public_id, patient_public_id);
