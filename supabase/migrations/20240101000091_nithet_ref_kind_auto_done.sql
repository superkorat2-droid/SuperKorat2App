-- Migration 91: ประเภทเอกสารอ้างอิงของแผน + ตั้งนัดเป็น "เสร็จสิ้น" อัตโนมัติ
--
-- 1) ref_kind — งานบางเรื่องไม่มีคำสั่ง มีแค่หนังสือราชการ/บันทึกข้อความ
--    เดิมทุกที่เขียนตายตัวว่า "คำสั่ง" (รายงาน A4 พิมพ์ "ตามคำสั่งเลขที่ ศธ.../ว123" ผิดความหมาย)
--    ค่าเริ่มต้น 'order' → ข้อมูลเดิมทุกแถวแสดงเหมือนเดิม
--    nithet_visits เก็บสำเนา (snapshot) แบบเดียวกับ order_number ตาม migration 77
--    กันด้วย order_guard เหมือนฟิลด์คำสั่งอื่น (เจ้าของนัด/ผู้มีสิทธิ์แผนเท่านั้น)
--
-- 2) บันทึกนิเทศ "สมบูรณ์" ที่ผูกนัดครบแล้ว → นัดเปลี่ยนเป็น done เอง
--    เดิมฟอร์มถามผู้บันทึกให้กดตั้งเอง แต่ผู้รับผิดชอบร่วม (ไม่ใช่เจ้าของนัด) แก้นัดไม่ได้ตาม RLS
--    นัดจึงค้าง "กำหนดการ" ถ้าหัวหน้างานกำหนดนัดแต่ไม่ได้ไปเอง
--    "ครบ" = นัดมีโรงเรียน → ทุกโรงในนัดมีบันทึกสมบูรณ์อย่างน้อย 1 ใบ · ไม่มีโรง → มีบันทึกสมบูรณ์ 1 ใบ
--    SECURITY DEFINER เพื่อข้าม RLS ของ nithet_events (แก้แค่ status เท่านั้น)
--    order_guard ยังทำงานตอน UPDATE นี้ แต่ไม่มีอะไรเปลี่ยนในฟิลด์คำสั่ง จึงไม่กระทบ

-- 1) ────────────────────────────────────────────────────────────────
ALTER TABLE public.nithet_events
  ADD COLUMN ref_kind text NOT NULL DEFAULT 'order'
  CONSTRAINT nithet_events_ref_kind_chk CHECK (ref_kind IN ('order', 'letter', 'memo'));
ALTER TABLE public.nithet_visits
  ADD COLUMN ref_kind text NOT NULL DEFAULT 'order'
  CONSTRAINT nithet_visits_ref_kind_chk CHECK (ref_kind IN ('order', 'letter', 'memo'));
COMMENT ON COLUMN public.nithet_events.ref_kind IS
  'ประเภทเอกสารอ้างอิงของ order_number: order=คำสั่ง · letter=หนังสือราชการ · memo=บันทึกข้อความ';
COMMENT ON COLUMN public.nithet_visits.ref_kind IS
  'สำเนา ref_kind จาก nithet_events ตอนเลือกแผน (คู่กับ order_number)';

CREATE OR REPLACE FUNCTION public.nithet_events_order_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF public.can_manage_nithet_plan() THEN RETURN NEW; END IF;

  -- เจ้าของนัดจัดการข้อมูลคำสั่งในนัดของตัวเองได้ (migration 90)
  IF TG_OP = 'INSERT' AND NEW.created_by IS NOT NULL AND NEW.created_by = auth.uid() THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.created_by IS NOT NULL AND OLD.created_by = auth.uid() THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.order_number := '';
    NEW.order_date   := NULL;
    NEW.order_link   := '';
    NEW.doc_links    := '[]'::jsonb;
    NEW.topics       := '{}';
    NEW.ref_kind     := 'order';
  ELSE
    NEW.order_number := OLD.order_number;
    NEW.order_date   := OLD.order_date;
    NEW.order_link   := OLD.order_link;
    NEW.doc_links    := OLD.doc_links;
    NEW.topics       := OLD.topics;
    NEW.ref_kind     := OLD.ref_kind;
  END IF;
  RETURN NEW;
END;
$$;

-- 2) ────────────────────────────────────────────────────────────────
-- เช็คว่านัดหนึ่ง "บันทึกครบ" แล้วหรือยัง แล้วตั้งเป็น done (เฉพาะนัดที่ยัง scheduled)
CREATE OR REPLACE FUNCTION public.nithet_event_mark_done_if_complete(p_event_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_schools uuid[];
  v_need    int;
  v_done    int;
BEGIN
  SELECT school_ids INTO v_schools
  FROM public.nithet_events WHERE id = p_event_id AND status = 'scheduled';
  IF NOT FOUND THEN RETURN; END IF;

  v_need := COALESCE(array_length(v_schools, 1), 0);
  IF v_need > 0 THEN
    SELECT count(DISTINCT v.school_id) INTO v_done
    FROM public.nithet_visits v
    WHERE v.event_id = p_event_id AND v.status = 'final' AND v.school_id = ANY (v_schools);
  ELSE
    v_need := 1;
    SELECT count(*) INTO v_done
    FROM public.nithet_visits v
    WHERE v.event_id = p_event_id AND v.status = 'final';
  END IF;

  IF v_done >= v_need THEN
    UPDATE public.nithet_events SET status = 'done'
    WHERE id = p_event_id AND status = 'scheduled';
  END IF;
END;
$$;
-- เรียกจาก trigger เท่านั้น ไม่เปิดให้ผู้ใช้เรียกตรง
REVOKE EXECUTE ON FUNCTION public.nithet_event_mark_done_if_complete(uuid) FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.nithet_visits_auto_done()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NEW.event_id IS NOT NULL AND NEW.status = 'final' THEN
    PERFORM public.nithet_event_mark_done_if_complete(NEW.event_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_nithet_visits_auto_done ON public.nithet_visits;
CREATE TRIGGER trg_nithet_visits_auto_done
  AFTER INSERT OR UPDATE OF status, event_id, school_id ON public.nithet_visits
  FOR EACH ROW EXECUTE FUNCTION public.nithet_visits_auto_done();
