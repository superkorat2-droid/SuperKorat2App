-- patch_news_html.sql
-- เพิ่มคอลัมน์ html_code สำหรับแทรก HTML+JS แบบกำหนดเอง
-- รัน 1 ครั้ง — ปลอดภัยรันซ้ำ

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'news' AND column_name = 'html_code'
  ) THEN
    ALTER TABLE public.news ADD COLUMN html_code text NOT NULL DEFAULT '';
  END IF;
END $$;
