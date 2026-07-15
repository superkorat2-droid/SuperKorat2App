-- Migration 50: จัดวางตัวหนังสือ (ซ้าย/กลาง) + ซ่อน header ทั้งแถบ ต่อหน้า CMS
-- (page_headers ใน area_config เป็น jsonb ไม่ต้อง migrate schema — เพิ่ม key align/hidden ตรงในโค้ดได้เลย)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='header_align') THEN
    ALTER TABLE public.pages ADD COLUMN header_align text NOT NULL DEFAULT 'center'
      CHECK (header_align IN ('left','center'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='header_hidden') THEN
    ALTER TABLE public.pages ADD COLUMN header_hidden boolean NOT NULL DEFAULT false;
  END IF;
END $$;
