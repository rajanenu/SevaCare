-- Close the check-then-insert double-booking race in bookAppointment/reschedule:
-- two parallel requests could both pass the "is this exact slot free?" read and
-- then both insert an 'upcoming' appointment for the same doctor + time. Make the
-- database the single arbiter with a partial unique index.
--
-- Scope matters:
--   * Only SLOT bookings have a real time grid. TOKEN bookings deliberately share
--     a session-start slot string (every morning token maps to "<date> 09:00"),
--     so they MUST be excluded — their uniqueness is the atomic token counter,
--     not the clock. booking_type = 'SLOT' does that.
--   * Only 'upcoming' rows compete for a slot; a cancelled or completed
--     appointment frees the time for rebooking, so the partial predicate lets a
--     new 'upcoming' booking coexist with an old 'cancelled' one at the same time.
CREATE UNIQUE INDEX IF NOT EXISTS uq_${tenantSchema}_appt_slot_upcoming
    ON ${tenantSchema}.appointment (doctor_public_id, appointment_slot)
    WHERE appointment_status = 'upcoming' AND booking_type = 'SLOT';
