-- Migration 55: คอลัมน์ลิงก์เพิ่มเติมท้ายเว็บไซต์ — admin ตั้งหัวข้อ + สร้างลิงก์เองได้
-- (internal route หรือ external URL) เหมือน pattern ของ area_config.services แต่แยกจากกัน
-- เพราะ services ใช้แสดงบนหน้าแรก (E-Service Center) คนละจุดประสงค์กับ footer
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='footer_extra_title') THEN
    ALTER TABLE public.area_config ADD COLUMN footer_extra_title text NOT NULL DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='footer_extra_links') THEN
    ALTER TABLE public.area_config ADD COLUMN footer_extra_links jsonb NOT NULL DEFAULT '[]'::jsonb;
  END IF;
END $$;
