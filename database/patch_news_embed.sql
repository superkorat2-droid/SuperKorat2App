-- patch_news_embed.sql
-- เพิ่มคอลัมน์สำหรับ embed URL, show_cover, show_title
-- รัน 1 ครั้ง — ปลอดภัยถ้ารันซ้ำ (ใช้ DO $$ IF NOT EXISTS)

DO $$ BEGIN

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'news' AND column_name = 'embed_url'
  ) THEN
    ALTER TABLE public.news ADD COLUMN embed_url text NOT NULL DEFAULT '';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'news' AND column_name = 'embed_type'
  ) THEN
    ALTER TABLE public.news ADD COLUMN embed_type text NOT NULL DEFAULT '';
    -- ค่าที่รองรับ: '' | 'youtube' | 'drive' | 'slides' | 'canva' | 'pdf' | 'iframe'
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'news' AND column_name = 'show_cover'
  ) THEN
    ALTER TABLE public.news ADD COLUMN show_cover boolean NOT NULL DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'news' AND column_name = 'show_title'
  ) THEN
    ALTER TABLE public.news ADD COLUMN show_title boolean NOT NULL DEFAULT true;
  END IF;

END $$;
