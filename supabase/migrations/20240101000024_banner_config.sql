-- Migration 24: banner aspect ratio + schools page config (รวม columns ที่เพิ่มผ่าน docker exec)
ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS banner_aspect_ratio  text DEFAULT '21:9',
  ADD COLUMN IF NOT EXISTS schools_page_title   text DEFAULT 'ทำเนียบสถานศึกษา',
  ADD COLUMN IF NOT EXISTS schools_page_subtitle text DEFAULT '';
