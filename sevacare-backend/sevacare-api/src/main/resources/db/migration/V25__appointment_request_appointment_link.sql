-- V25: Link a confirmed QR appointment request to the real tenant-schema appointment
-- it created. Previously confirmAndCreateAppointment only flipped request_status —
-- it never created a patient/appointment row, so a QR-booked patient never showed up
-- in the doctor's consult queue. Now it does, and this column records the link.

ALTER TABLE public.appointment_request ADD COLUMN IF NOT EXISTS appointment_public_id VARCHAR(16);
