-- Completion stamp for the measured consult pace: queue ETAs are computed from
-- gaps between consecutive completed_at values for a doctor's day, replacing the
-- hardcoded 10/15-minute guesses that estimatedWaitMinutes/avgConsultMinutes
-- previously served.
ALTER TABLE ${tenantSchema}.appointment ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP;
