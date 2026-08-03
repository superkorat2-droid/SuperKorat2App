-- ═══════════════════════════════════════════════════════════════════════
-- footer: เบอร์โทรแยกตามกลุ่มงาน + แผนที่กดแล้วนำทาง
--
-- เดิม footer มีเบอร์กลางเบอร์เดียว (contact_phone) คนที่อยากติดต่อกลุ่มงานใด
-- กลุ่มงานหนึ่งต้องโทรเข้ากลางแล้วให้โอนต่อ และทั้งเว็บไม่มีแผนที่ให้กดนำทางเลย
--
-- ⚠️ ทำไมไม่เก็บเบอร์ไว้ใน personnel_groups: ตัวนั้นมีแค่ 5 กลุ่ม แต่หน่วยงานที่ต้อง
-- แสดงเบอร์มี 10 และมันเป็นของ load-bearing ~20 ไฟล์ (profiles.department จับคู่ด้วย
-- label ส่วน nithet_events/supervision_forms.responsible_group จับด้วย key)
-- เติมกลุ่มใหม่เข้าไป = ตัวกรองบุคลากร ผังองค์กร dropdown เอกสาร เปลี่ยนตามหมด
-- จึงแยกเป็นคอลัมน์ของตัวเอง แล้วให้หน้าแอดมินมีปุ่ม "เติมจากกลุ่มงานบุคลากร" แทน
--
-- contact_phones = [{ label, phone, order }]  — รูปร่างเดียวกับ footer_extra_links
-- ตั้งใจให้เหมือนกันเพื่อให้ลอกตัวแก้ไขในหน้าตั้งค่ามาใช้ได้ทั้งชุด
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS contact_phones jsonb NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS map_image_url  text   NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS map_lat        numeric(10,7),
  ADD COLUMN IF NOT EXISTS map_lng        numeric(10,7),
  ADD COLUMN IF NOT EXISTS map_link       text   NOT NULL DEFAULT '';

COMMENT ON COLUMN public.area_config.contact_phones IS
  'เบอร์ติดต่อแต่ละกลุ่มงานที่แสดงท้ายเว็บ [{label, phone, order}] — คนละชุดกับ personnel_groups โดยตั้งใจ';
COMMENT ON COLUMN public.area_config.map_image_url IS
  'ภาพแผนที่สำนักงานที่แอดมินอัปเอง — ว่างได้ จะตกไปเป็นการ์ดไอคอนหมุดแทน';
COMMENT ON COLUMN public.area_config.map_link IS
  'ลิงก์ Google Maps ที่วางเอง ใช้เมื่อไม่ได้กรอก map_lat/map_lng';

-- get_area_config() (SECURITY DEFINER) คืน row_to_json(a) ทั้งแถว คอลัมน์ใหม่จึงไหลไปหน้าเว็บเอง
-- แต่ useAreaConfig.js มีทางสำรองที่ยิง .from('area_config') ตรง ๆ ซึ่ง migration 0062
-- REVOKE SELECT จาก anon ไว้แล้ว → ต้อง grant รายคอลัมน์ ไม่งั้นทางสำรองพังเงียบ
GRANT SELECT (contact_phones, map_image_url, map_lat, map_lng, map_link)
  ON public.area_config TO anon;

NOTIFY pgrst, 'reload schema';
