-- Welcome popup (ป๊อปอัปต้อนรับก่อนเข้าเว็บ) เปิด/ปิดและตั้งค่าได้จาก admin
ALTER TABLE public.area_config ADD COLUMN IF NOT EXISTS welcome_popup_enabled boolean NOT NULL DEFAULT false;
ALTER TABLE public.area_config ADD COLUMN IF NOT EXISTS welcome_popup_image_url text NOT NULL DEFAULT '';
ALTER TABLE public.area_config ADD COLUMN IF NOT EXISTS welcome_popup_link_url text NOT NULL DEFAULT '';
