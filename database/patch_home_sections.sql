-- patch_home_sections.sql
-- เพิ่ม home_sections JSONB ใน area_config สำหรับจัดการ section หน้าแรก
-- รัน 1 ครั้ง — ปลอดภัยรันซ้ำ

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'area_config' AND column_name = 'home_sections'
  ) THEN
    ALTER TABLE public.area_config ADD COLUMN home_sections JSONB;
  END IF;
END $$;

-- ตั้งค่า default sections สำหรับ row ที่ยังไม่มีค่า
UPDATE public.area_config
SET home_sections = '[
  {"key":"news",     "label":"ข่าวสาร",      "title":"ข่าวสารและประชาสัมพันธ์",            "visible":true, "bg":"#ffffff", "order":1},
  {"key":"services", "label":"บริการออนไลน์", "title":"บริการออนไลน์",                      "visible":true, "bg":"#f8fafc", "order":2},
  {"key":"cta",      "label":"CTA Banner",    "title":"ระบบกลุ่มนิเทศ ติดตามและประเมินผล", "visible":true, "bg":"#ffffff", "order":3}
]'::jsonb
WHERE home_sections IS NULL;
