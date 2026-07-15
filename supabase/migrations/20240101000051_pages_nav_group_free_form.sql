-- Migration 51: nav_group เคยล็อกไว้แค่ 4 ค่า (general/work/service/other) จากยุคก่อนมี custom group
-- แต่ migration 11 เปิดให้แอดมินสร้างกลุ่มเมนูใหม่แบบ free-form ผ่าน area_config.nav_groups (key เช่น group_<timestamp>)
-- โดยไม่เคยแก้ constraint นี้ตาม — ผลคือสร้างหน้าใหม่แล้ว assign เข้ากลุ่มที่สร้างเองไม่ได้เลย (insert ชน check constraint เงียบๆ)
ALTER TABLE public.pages DROP CONSTRAINT IF EXISTS pages_nav_group_check;
