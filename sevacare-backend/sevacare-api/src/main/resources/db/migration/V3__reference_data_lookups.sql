CREATE TABLE IF NOT EXISTS public.specialization_master (
    specialization_name VARCHAR(120) PRIMARY KEY,
    display_order INT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS public.city_master (
    city_name VARCHAR(120) PRIMARY KEY,
    display_order INT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT true
);

INSERT INTO public.specialization_master (specialization_name, display_order, active)
VALUES
    ('Cardiologist', 1, true),
    ('Neurologist', 2, true),
    ('Gynecologist', 3, true),
    ('Skin Specialist', 4, true),
    ('General Physician', 5, true)
ON CONFLICT (specialization_name) DO UPDATE SET display_order = EXCLUDED.display_order, active = EXCLUDED.active;

INSERT INTO public.city_master (city_name, display_order, active)
VALUES
    ('Hyderabad', 1, true),
    ('Bengaluru', 2, true),
    ('Mumbai', 3, true),
    ('Chennai', 4, true),
    ('Delhi', 5, true)
ON CONFLICT (city_name) DO UPDATE SET display_order = EXCLUDED.display_order, active = EXCLUDED.active;
