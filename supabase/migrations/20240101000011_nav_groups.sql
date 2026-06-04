-- Migration 11: nav_groups config in area_config
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='nav_groups') THEN
    ALTER TABLE public.area_config ADD COLUMN nav_groups jsonb DEFAULT NULL;
  END IF;
END $$;

UPDATE public.area_config SET nav_groups = '[
  {"key":"general", "label":"ข้อมูลทั่วไป",     "visible":true, "order":1},
  {"key":"work",    "label":"งานนิเทศติดตาม",   "visible":true, "order":2},
  {"key":"service", "label":"บริการ",            "visible":true, "order":3},
  {"key":"other",   "label":"อื่นๆ",             "visible":false,"order":4}
]'::jsonb
WHERE nav_groups IS NULL;
