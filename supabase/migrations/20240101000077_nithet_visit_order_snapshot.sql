-- (0.2) ประเภทนิเทศ "อื่นๆ" พิมพ์ระบุเองได้ + (Phase 2) snapshot ข้อมูลคำสั่งจากแผนลงในบันทึกจริง
--
-- snapshot ไม่ join สด — ตาม pattern เดิมที่ title/visit_date/work_group ถูก copy จาก
-- nithet_events ตอน prefill อยู่แล้ว (AdminNitetVisitEditorView.vue) เพื่อให้บันทึกที่บันทึกไปแล้ว
-- ไม่เปลี่ยนความหมายตามหลังถ้าแผนต้นทางถูกแก้ไข/ลบทีหลัง

ALTER TABLE public.nithet_visits
  ADD COLUMN IF NOT EXISTS visit_type_other text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS order_number     text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS order_date       date,
  ADD COLUMN IF NOT EXISTS order_link       text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS doc_links        jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.nithet_visits.visit_type_other IS
  'ข้อความระบุเองเมื่อ visit_type=''other'' — ไม่บังคับกรอก';
COMMENT ON COLUMN public.nithet_visits.order_number IS
  'สำเนาเลขที่คำสั่งจาก nithet_events ตอนเลือกแผน (ไม่ join สด) แก้ไม่ได้จากฟอร์มบันทึกผล';

-- เผยแพร่ visit_type_other บนหน้าสาธารณะด้วย — อ่อนไหวเท่า ๆ กับ visit_type ที่เปิดอยู่แล้ว
-- (order_number/order_date/order_link/doc_links ไม่เปิด เพราะไม่จำเป็นสำหรับผู้อ่านทั่วไป)
CREATE OR REPLACE VIEW public.nithet_visits_public AS
  SELECT v.id, v.visit_date, v.visit_type, v.title, v.topics,
         v.summary, v.strengths, v.photos, v.links,
         v.academic_year, v.term, v.created_at,
         v.place_name,
         s.name         AS school_name,
         s.district     AS school_district,
         s.school_group AS school_group,
         COALESCE(
           NULLIF(btrim(p.full_name), ''),
           NULLIF(btrim(concat_ws(' ', p.title, p.first_name, p.last_name)), '')
         ) AS supervisor_name,
         p.position AS supervisor_position,
         v.visit_type_other
  FROM public.nithet_visits v
  LEFT JOIN public.schools  s ON s.id = v.school_id
  LEFT JOIN public.profiles p ON p.id = v.created_by
  WHERE v.is_public = true AND v.status = 'final';

GRANT SELECT ON public.nithet_visits_public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
