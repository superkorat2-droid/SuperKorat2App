-- หัวข้อบล็อกผู้บริหาร 3 ชั้นบนหน้าทำเนียบบุคลากร — ให้แอดมินแก้เองได้
--
-- เดิมฮาร์ดโค้ดอยู่ใน PersonnelDirectory.vue 3 จุด
--   'ผู้อำนวยการเขตพื้นที่การศึกษา' / 'รองผู้อำนวยการเขตพื้นที่การศึกษา' / 'ผู้อำนวยการกลุ่ม'
-- อยากเปลี่ยนคำทีต้องแก้โค้ดแล้ว deploy ใหม่ทุกครั้ง
--
-- ตั้งใจทำแค่ "ชื่อ" ไม่ทำ "ลำดับ": สามชั้นนี้เป็นลำดับชั้นการบังคับบัญชา
-- (ผอ.เขต → รอง ผอ. → ผอ.กลุ่ม) ซึ่งไม่มีเหตุให้สลับ และถ้าเอาไปปนกับรายการ
-- กลุ่มงานในหน้าแอดมินจะมี 3 แถวที่ลบไม่ได้/ทำงานไม่เหมือนแถวอื่นโผล่มากวน
--
-- รูปแบบ: {"director": "...", "deputy": "...", "group_director": "..."}
-- คีย์ไหนว่างหรือไม่มี = ใช้ค่าเริ่มต้นใน SECTION_TITLE_DEFAULTS (usePersonnel.js)
-- จึงปลอดภัยที่จะปล่อยเป็น {} และไม่ต้อง backfill ข้อมูลเดิม

ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS personnel_section_titles jsonb NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN public.area_config.personnel_section_titles IS
  'หัวข้อบล็อก ผอ.เขต/รอง ผอ./ผอ.กลุ่ม บนหน้าทำเนียบบุคลากร '
  '{"director","deputy","group_director"} — คีย์ที่ว่างหรือไม่มี = ใช้ค่าเริ่มต้นในโค้ด';

-- ⚠️ 0062 REVOKE ทั้งตารางจาก anon แล้ว re-grant เป็นรายคอลัมน์
-- ตอนนี้ useAreaConfig.js อ่านผ่าน RPC get_area_config() (SECURITY DEFINER) อย่างเดียว
-- จึงยังไม่จำเป็น แต่ให้ไว้กันโค้ดในอนาคตที่ query ตารางตรงแล้วพังเงียบ ๆ
GRANT SELECT (personnel_section_titles) ON public.area_config TO anon;

-- get_area_config() ใช้ row_to_json() คอลัมน์ใหม่จึงโผล่เองโดยไม่ต้องแก้ฟังก์ชัน
NOTIFY pgrst, 'reload schema';
