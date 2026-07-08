-- Migration 35: สัดส่วนกรอบ header รูป/วิดีโอ ต่อหน้า CMS (page_headers ใน area_config เป็น jsonb ไม่ต้อง migrate schema)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='header_aspect_ratio') THEN
    ALTER TABLE public.pages ADD COLUMN header_aspect_ratio text NOT NULL DEFAULT '21:9';
  END IF;
END $$;
