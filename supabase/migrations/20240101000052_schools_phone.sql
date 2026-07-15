-- Migration 52: schools.phone column was missing — the edit form (AdminSchoolsView.vue) has always
-- sent a "phone" field on save, but the column never existed, so any save on the school edit form
-- failed with "Could not find the 'phone' column of 'schools' in the schema cache".
-- Nullable (not NOT NULL DEFAULT '') to match how the form already sends null for empty optional fields.
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='schools' AND column_name='phone') THEN
    ALTER TABLE public.schools ADD COLUMN phone text;
  END IF;
END $$;
