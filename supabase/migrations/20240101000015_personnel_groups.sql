-- Migration 15: personnel_groups config in area_config
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='personnel_groups') THEN
    ALTER TABLE public.area_config ADD COLUMN personnel_groups jsonb DEFAULT NULL;
  END IF;
END $$;

-- ค่า default (ปรับให้ตรงกับโครงสร้างจริง)
UPDATE public.area_config
SET personnel_groups = '[
  {"key":"nitet",    "label":"กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา", "visible":true, "order":1},
  {"key":"promote",  "label":"กลุ่มส่งเสริมการจัดการศึกษา",                 "visible":true, "order":2},
  {"key":"personnel","label":"กลุ่มบริหารงานบุคคล",                         "visible":true, "order":3},
  {"key":"budget",   "label":"กลุ่มบริหารงบประมาณ",                         "visible":true, "order":4},
  {"key":"general",  "label":"กลุ่มอำนวยการ",                               "visible":true, "order":5}
]'::jsonb
WHERE personnel_groups IS NULL;
