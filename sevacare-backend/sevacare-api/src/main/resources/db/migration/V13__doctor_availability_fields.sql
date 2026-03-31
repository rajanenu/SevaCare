-- Add doctor availability date and ready-to-look-patients fields
-- Applies to both tenant schemas

ALTER TABLE tenant_t_1001.doctor 
ADD COLUMN IF NOT EXISTS available_from DATE,
ADD COLUMN IF NOT EXISTS ready_to_look_patients BOOLEAN DEFAULT true;

ALTER TABLE tenant_t_1002.doctor 
ADD COLUMN IF NOT EXISTS available_from DATE,
ADD COLUMN IF NOT EXISTS ready_to_look_patients BOOLEAN DEFAULT true;
