-- แบบนิเทศ: รูปหน้าปกของแบบฟอร์ม + รูปประกอบต่อคำถาม
ALTER TABLE public.supervision_forms ADD COLUMN IF NOT EXISTS cover_image_url text NOT NULL DEFAULT '';
ALTER TABLE public.supervision_questions ADD COLUMN IF NOT EXISTS image_url text NOT NULL DEFAULT '';
