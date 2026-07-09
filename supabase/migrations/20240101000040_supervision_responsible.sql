-- แบบนิเทศ: ผู้รับผิดชอบ (แยกจาก created_by) หลายคนหรือมอบทั้งกลุ่ม + ตัวเลือกแสดง/ซ่อนต่อผู้ตอบ
ALTER TABLE public.supervision_forms ADD COLUMN IF NOT EXISTS responsible_ids uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE public.supervision_forms ADD COLUMN IF NOT EXISTS responsible_group text NOT NULL DEFAULT '';
ALTER TABLE public.supervision_forms ADD COLUMN IF NOT EXISTS show_responsible boolean NOT NULL DEFAULT false;
