-- The doctor's day queue is now cut in SQL with
-- (doctor_public_id, appointment_slot BETWEEN day-start AND day-end); give that
-- read its composite index. The existing single-column indexes each cover only
-- half of the predicate, and this is the most-polled query in the product.
CREATE INDEX IF NOT EXISTS idx_${tenantSchema}_appt_doctor_slot
    ON ${tenantSchema}.appointment (doctor_public_id, appointment_slot);
