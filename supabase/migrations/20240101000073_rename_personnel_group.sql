-- ══════════════════════════════════════════════════════════════════════════
-- เปลี่ยนชื่อกลุ่มงานแล้วให้ข้อมูลที่ผูกไว้ตามไปด้วย
-- ══════════════════════════════════════════════════════════════════════════
--
-- ปัญหาที่แก้ (เจอจริงบน production 20 ส.ค. 2569):
--   ชื่อกลุ่มงานถูกเก็บไว้ 2 ที่ที่ต้องตรงกันเป๊ะ ๆ
--     1. area_config.personnel_groups[].label  ← ที่แอดมินพิมพ์แก้ได้
--     2. profiles.department                    ← ที่ผูกกับตัวบุคลากรแต่ละคน
--   หน้า /personnel หาลำดับของกลุ่มด้วยการจับคู่ "ชื่อ" ของสองที่นี้
--   (PersonnelDirectory.vue → cfg.find(g => g.label === dep))
--
--   พอแอดมินแก้ชื่อในหน้าจัดการบุคลากร ระบบบันทึกแค่ที่ (1) ที่ (2) ยังเป็นชื่อเดิม
--   → จับคู่ไม่ติด → กลุ่มนั้นตกไปเป็นลำดับ 99 ทั้งหมด
--   อาการที่ผู้ใช้เห็น: "งานธุรการ" (กลุ่มเดียวที่ชื่อไม่ถูกแก้ จึงยังจับคู่ติดที่ลำดับ 8)
--   เด้งขึ้นมาอยู่เป็นกลุ่มแรกต่อจาก ผอ.กลุ่ม ส่วนที่เหลือเรียงตามตัวอักษรมั่วไปหมด
--
-- ทำไมไม่เปลี่ยนไปเก็บเป็น key แทน label:
--   ในระบบมี 2 ธรรมเนียมปนกันอยู่แล้ว (library_items.group_key / nithet_events
--   .responsible_group เก็บ key ส่วน profiles.department เก็บ label) การย้าย
--   profiles.department ไปเป็น key ต้องแก้อีกกว่า 20 ไฟล์ที่อ่าน/กรองด้วย label
--   และ view personnel_public + โค้ดฝัง /embed/personnel ด้วย — เสี่ยงเกินเหตุ
--   ตัวนี้แก้ที่ "ตอนเปลี่ยนชื่อ" แทน ซึ่งเป็นจุดเดียวที่ทำให้สองที่หลุดจากกัน
--
-- ที่ที่เก็บชื่อกลุ่มงานเป็น label และต้องตามไปแก้:
--   profiles.department           บุคลากรสังกัดกลุ่มไหน (ตัวที่ทำให้เกิดบัค)
--   document_tasks.department     งานธุรการมอบหมายให้กลุ่มไหน
--   documents.publisher_dept      เอกสารเผยแพร่โดยกลุ่มไหน
--   area_config.contact_phones[]  เบอร์โทรกลุ่มงานใน footer (แยกกันโดยตั้งใจ
--                                 ดู migration 0069 — แต่ถ้าชื่อตรงกันก็ควรตามไปด้วย
--                                 ไม่งั้น footer จะโชว์ชื่อกลุ่มเก่าค้างอยู่)

CREATE OR REPLACE FUNCTION public.rename_personnel_group(p_old text, p_new text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  n_profiles int := 0;
  n_tasks    int := 0;
  n_docs     int := 0;
  n_phones   int := 0;
BEGIN
  -- ต้องเป็นแอดมินเท่านั้น — verify_jwt กันคนนอกไม่ได้ (anon key ผ่านได้)
  -- จึงต้องตรวจสิทธิ์เองในฟังก์ชัน
  IF public.get_my_role() NOT IN ('admin', 'super_admin') THEN
    RAISE EXCEPTION 'forbidden: ต้องเป็นผู้ดูแลระบบเท่านั้น';
  END IF;

  p_old := btrim(COALESCE(p_old, ''));
  p_new := btrim(COALESCE(p_new, ''));

  IF p_old = '' OR p_new = '' OR p_old = p_new THEN
    RETURN jsonb_build_object('profiles', 0, 'document_tasks', 0, 'documents', 0, 'contact_phones', 0);
  END IF;

  UPDATE public.profiles SET department = p_new WHERE department = p_old;
  GET DIAGNOSTICS n_profiles = ROW_COUNT;

  UPDATE public.document_tasks SET department = p_new WHERE department = p_old;
  GET DIAGNOSTICS n_tasks = ROW_COUNT;

  UPDATE public.documents SET publisher_dept = p_new WHERE publisher_dept = p_old;
  GET DIAGNOSTICS n_docs = ROW_COUNT;

  -- contact_phones เป็น jsonb array [{label, phone, order}] — แก้เฉพาะ element ที่ label ตรง
  UPDATE public.area_config
  SET contact_phones = (
        SELECT jsonb_agg(
                 CASE WHEN btrim(e->>'label') = p_old
                      THEN jsonb_set(e, '{label}', to_jsonb(p_new))
                      ELSE e END
                 ORDER BY ord
               )
        FROM jsonb_array_elements(contact_phones) WITH ORDINALITY AS t(e, ord)
      )
  WHERE id = 1
    AND contact_phones IS NOT NULL
    AND jsonb_typeof(contact_phones) = 'array'
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(contact_phones) e
      WHERE btrim(e->>'label') = p_old
    );
  GET DIAGNOSTICS n_phones = ROW_COUNT;

  RETURN jsonb_build_object(
    'profiles',       n_profiles,
    'document_tasks', n_tasks,
    'documents',      n_docs,
    'contact_phones', n_phones
  );
END;
$$;

REVOKE ALL ON FUNCTION public.rename_personnel_group(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rename_personnel_group(text, text) TO authenticated;

COMMENT ON FUNCTION public.rename_personnel_group(text, text) IS
  'เปลี่ยนชื่อกลุ่มงานจาก p_old เป็น p_new ในทุกตารางที่เก็บชื่อกลุ่มเป็นข้อความ '
  'เรียกจากหน้าจัดการบุคลากรตอนกดบันทึกกลุ่มงาน คืนจำนวนแถวที่แก้ไปแต่ละตาราง';
