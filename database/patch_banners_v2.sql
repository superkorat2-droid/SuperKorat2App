-- patch_banners_v2.sql
-- เพิ่ม column ใหม่ให้ banners table (is_pinned, link_type, description)

DO $$
BEGIN
  -- is_pinned: ปักหมุด — แสดงก่อนแบนเนอร์อื่น
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='banners' AND column_name='is_pinned'
  ) THEN
    ALTER TABLE public.banners ADD COLUMN is_pinned boolean NOT NULL DEFAULT false;
    RAISE NOTICE '✅ Added: banners.is_pinned';
  ELSE
    RAISE NOTICE '⏭ Skip: is_pinned (exists)';
  END IF;

  -- link_type: ประเภทลิงค์ — none | internal | external
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='banners' AND column_name='link_type'
  ) THEN
    ALTER TABLE public.banners ADD COLUMN link_type text NOT NULL DEFAULT 'none';
    RAISE NOTICE '✅ Added: banners.link_type';
  ELSE
    RAISE NOTICE '⏭ Skip: link_type (exists)';
  END IF;

  -- description: คำอธิบายยาว (ต่างจาก subtitle ที่สั้น)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='banners' AND column_name='description'
  ) THEN
    ALTER TABLE public.banners ADD COLUMN description text NOT NULL DEFAULT '';
    RAISE NOTICE '✅ Added: banners.description';
  ELSE
    RAISE NOTICE '⏭ Skip: description (exists)';
  END IF;

  -- banner_type check: รองรับ 'youtube' เพิ่มเติม
  RAISE NOTICE '✅ banner_type supports: image | video | youtube';

END $$;

-- ตรวจสอบ
SELECT id, title, banner_type, is_active, is_pinned, link_type
FROM public.banners
ORDER BY is_pinned DESC, sort_order ASC;
