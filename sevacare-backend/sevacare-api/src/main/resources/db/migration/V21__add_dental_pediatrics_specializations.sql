-- V21: Add Dental and Pediatrics to the global specialization_master table
INSERT INTO public.specialization_master (specialization_name, display_order, active)
VALUES
    ('Dental',     6, true),
    ('Pediatrics', 7, true)
ON CONFLICT (specialization_name) DO UPDATE SET display_order = EXCLUDED.display_order, active = EXCLUDED.active;
