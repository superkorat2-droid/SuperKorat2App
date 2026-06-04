-- Migration 16: services config in area_config
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='services') THEN
    ALTER TABLE public.area_config ADD COLUMN services jsonb DEFAULT NULL;
  END IF;
END $$;

UPDATE public.area_config SET services = '[
  {"key":"nitet",    "label":"กลุ่มนิเทศติดตามฯ",    "icon":"eye",       "type":"internal","url":"/nithet",     "visible":true,"order":1},
  {"key":"download", "label":"ดาวน์โหลดเอกสาร",      "icon":"download",  "type":"internal","url":"/download",   "visible":true,"order":2},
  {"key":"qrcode",   "label":"สร้าง QR Code",         "icon":"qrcode",    "type":"internal","url":"/qrcode",     "visible":true,"order":3},
  {"key":"urlshort", "label":"ย่อลิงค์",              "icon":"link",      "type":"internal","url":"/url-short",  "visible":true,"order":4},
  {"key":"sar",      "label":"ระบบ SAR Online",        "icon":"chart-bar", "type":"external","url":"",            "visible":true,"order":5},
  {"key":"media",    "label":"คลังสื่อนวัตกรรม",      "icon":"beaker",    "type":"external","url":"",            "visible":true,"order":6},
  {"key":"training", "label":"ลงทะเบียนอบรม",         "icon":"clipboard", "type":"external","url":"",            "visible":true,"order":7},
  {"key":"contact",  "label":"ติดต่อเรา",              "icon":"phone",     "type":"internal","url":"/contact",   "visible":true,"order":8}
]'::jsonb
WHERE services IS NULL;
