-- Migration 90: เชื่อมปฏิทินนิเทศ ↔ บันทึกนิเทศ + รองรับประชุม/อบรม
--
-- 1) ประเภทบันทึกเพิ่ม 'training' (อบรม/สัมมนา) — ปฏิทินมี training อยู่แล้ว แต่บันทึกไม่มี
--    เดิมฟอร์มแปลง training → speaker (เป็นวิทยากร) ซึ่งผิดความหมาย
-- 2) ศน. เจ้าของนัดใส่ เลขที่คำสั่ง/ลิงก์/เอกสาร/ประเด็นย่อย ในนัดของตัวเองได้
--    (เดิมต้องมีสิทธิ์ can_manage_nithet_plan เท่านั้น ไม่งั้น trigger ล้างทิ้งเงียบ ๆ)
--    นัดของคนอื่นยังแก้ไม่ได้อยู่ดี เพราะ RLS update = เจ้าของ/แอดมิน
--    ยังเป็น trigger ธรรมดา ไม่ใช่ SECURITY DEFINER (auth.uid() ต้องเป็นของผู้เรียกจริง)
-- 3) คนที่ถูกใส่ชื่อเป็นผู้รับผิดชอบร่วม (responsible_ids) อ่านนัดนั้นได้ แม้ผู้สร้างปิดเผยแพร่
-- 4) ปฏิทินสาธารณะแนบรายการบันทึกที่ผูกกับนัด — เฉพาะ is_public + final
--    (เงื่อนไขเดียวกับ view nithet_visits_public ไม่หลุดร่าง/จุดที่ควรพัฒนา/ข้อเสนอแนะ)

-- 1) ────────────────────────────────────────────────────────────────
ALTER TABLE public.nithet_visits DROP CONSTRAINT nithet_visits_type_chk;
ALTER TABLE public.nithet_visits ADD CONSTRAINT nithet_visits_type_chk
  CHECK (visit_type = ANY (ARRAY['school_visit','follow_up','meeting','training','speaker','other']));

-- 2) ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.nithet_events_order_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF public.can_manage_nithet_plan() THEN RETURN NEW; END IF;

  -- เจ้าของนัดจัดการข้อมูลคำสั่งในนัดของตัวเองได้
  IF TG_OP = 'INSERT' AND NEW.created_by IS NOT NULL AND NEW.created_by = auth.uid() THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.created_by IS NOT NULL AND OLD.created_by = auth.uid() THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.order_number := '';
    NEW.order_date   := NULL;
    NEW.order_link   := '';
    NEW.doc_links    := '[]'::jsonb;
    NEW.topics       := '{}';
  ELSE
    NEW.order_number := OLD.order_number;
    NEW.order_date   := OLD.order_date;
    NEW.order_link   := OLD.order_link;
    NEW.doc_links    := OLD.doc_links;
    NEW.topics       := OLD.topics;
  END IF;
  RETURN NEW;
END;
$$;

-- 3) ────────────────────────────────────────────────────────────────
DROP POLICY "nithet_events: select" ON public.nithet_events;
CREATE POLICY "nithet_events: select"
  ON public.nithet_events FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR created_by = auth.uid()
    OR auth.uid() = ANY (responsible_ids)
    OR (show_public = true AND auth.role() = 'authenticated')
  );

-- 4) ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_nithet_events_public()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
AS $function$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', e.id, 'type', e.type, 'title', e.title, 'description', e.description,
    'start_date', e.start_date, 'end_date', e.end_date,
    'start_time', e.start_time, 'end_time', e.end_time,
    'location', e.location, 'status', e.status,
    'schools', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'district', s.district) ORDER BY s.name)
      FROM public.schools s WHERE s.id = ANY(e.school_ids)
    ), '[]'::jsonb),
    'responsible_group', NULLIF(e.responsible_group, ''),
    'responsible_names', COALESCE((
      SELECT jsonb_agg(
        COALESCE(NULLIF(TRIM(CONCAT(p.title, p.first_name, CASE WHEN p.last_name > '' THEN ' ' || p.last_name ELSE '' END)), ''), p.full_name)
        ORDER BY p.first_name)
      FROM public.profiles p WHERE p.id = ANY(e.responsible_ids)
    ), '[]'::jsonb),
    'visits', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', v.id, 'title', v.title, 'visit_date', v.visit_date,
        'school_name', s.name, 'place_name', NULLIF(v.place_name, '')
      ) ORDER BY v.visit_date, s.name NULLS LAST)
      FROM public.nithet_visits v
      LEFT JOIN public.schools s ON s.id = v.school_id
      WHERE v.event_id = e.id AND v.is_public = true AND v.status = 'final'
    ), '[]'::jsonb)
  ) ORDER BY e.start_date, e.start_time NULLS LAST), '[]'::jsonb)
  FROM public.nithet_events e
  WHERE e.show_public = true AND e.status <> 'cancelled';
$function$;
