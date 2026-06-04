-- Migration 13: registration code in area_config
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='register_code_enabled') THEN
    ALTER TABLE public.area_config ADD COLUMN register_code_enabled boolean DEFAULT false;
    ALTER TABLE public.area_config ADD COLUMN register_code_teacher  text DEFAULT '';
    ALTER TABLE public.area_config ADD COLUMN register_code_personnel text DEFAULT '';
  END IF;
END $$;
