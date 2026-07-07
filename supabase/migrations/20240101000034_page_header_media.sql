-- Migration 34: page header media (image/video/gif) or default SVG icon+name
-- pages table (CMS pages) — per-row header, separate from nav_icon (menu) and in-body block images
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='header_mode') THEN
    ALTER TABLE public.pages ADD COLUMN header_mode text NOT NULL DEFAULT 'icon'
      CHECK (header_mode IN ('icon','media'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='header_media_url') THEN
    ALTER TABLE public.pages ADD COLUMN header_media_url text NOT NULL DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='header_media_type') THEN
    ALTER TABLE public.pages ADD COLUMN header_media_type text NOT NULL DEFAULT ''
      CHECK (header_media_type IN ('', 'image', 'gif', 'video'));
  END IF;
END $$;

-- area_config: page_headers JSONB — array keyed by route name, for static/system public pages
-- (ไม่ต้องแก้ get_area_config() เพราะมันคืน row_to_json(a) ทั้งแถวอยู่แล้ว คอลัมน์ใหม่ไหลผ่านอัตโนมัติ)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='page_headers') THEN
    ALTER TABLE public.area_config ADD COLUMN page_headers jsonb NOT NULL DEFAULT '[]'::jsonb;
  END IF;
END $$;
