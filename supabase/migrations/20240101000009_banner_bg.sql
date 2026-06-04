-- Migration 9: banner background columns in area_config
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='banner_bg') THEN
    ALTER TABLE public.area_config ADD COLUMN banner_bg      text DEFAULT '#0f172a';
    ALTER TABLE public.area_config ADD COLUMN banner_bg2     text DEFAULT '#1e3a5f';
    ALTER TABLE public.area_config ADD COLUMN banner_bg_type text DEFAULT 'solid';
  END IF;
END $$;
