-- Migration 49: เพิ่มคอลัมน์ home_gallery ใน area_config สำหรับเซกชัน "ภาพลิงค์" หน้าแรก
-- get_area_config() ใช้ row_to_json(a) จึงรวมคอลัมน์นี้เข้า response อัตโนมัติ ไม่ต้องแก้ RPC
ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS home_gallery jsonb DEFAULT '{"layout":"card","title":"","items":[]}'::jsonb;
