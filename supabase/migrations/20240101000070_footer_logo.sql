-- ═══════════════════════════════════════════════════════════════════════
-- โลโก้สำหรับ footer แยกจากโลโก้บนแถบนำทาง
--
-- เว็บนี้เป็นของ "กลุ่มนิเทศฯ" ซึ่งอยู่ภายใต้ "สำนักงานเขตพื้นที่การศึกษา"
-- โลโก้สองอันจึงคนละตัวกัน — บนหัวเว็บใช้ตราของกลุ่ม ส่วนท้ายเว็บอยากใช้
-- ตราของสำนักงานเขต ถ้าบังคับให้ใช้ logo_url ตัวเดียวจะเลือกได้แค่อย่างเดียว
--
-- ปล่อยว่างได้ → footer จะ fallback ไปใช้ logo_url เหมือนเดิม ของเดิมจึงไม่พัง
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS footer_logo_url text NOT NULL DEFAULT '';

COMMENT ON COLUMN public.area_config.footer_logo_url IS
  'โลโก้ที่แสดงท้ายเว็บ (ปกติเป็นตราสำนักงานเขต) — ว่าง = ใช้ logo_url แทน';

-- ต้อง grant รายคอลัมน์ เพราะ 0062 REVOKE ทั้งตารางจาก anon แล้ว
-- และ useAreaConfig.js มีทางสำรองที่ยิง .from('area_config') ตรง ถ้าลืมจะพังเงียบ
GRANT SELECT (footer_logo_url) ON public.area_config TO anon;

NOTIFY pgrst, 'reload schema';
