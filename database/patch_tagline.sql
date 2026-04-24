-- เพิ่ม column tagline ใน area_config
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='tagline'
  ) THEN
    ALTER TABLE public.area_config ADD COLUMN tagline text DEFAULT '';
    RAISE NOTICE '✅ Added: area_config.tagline';
  ELSE
    RAISE NOTICE '⏭ Skip: tagline (exists)';
  END IF;
END $$;

-- ตรวจสอบ
SELECT id, area_name, tagline FROM public.area_config WHERE id = 1;
