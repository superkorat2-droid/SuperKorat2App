-- ระบบ "รับทราบ" บันทึกการนิเทศ โดย ผอ.กลุ่มนิเทศ — ต้องรับทราบก่อนถึงจะพิมพ์รายงานได้
--
-- แยกจาก nithet_visits.status (draft/final) เด็ดขาด — status คือ "กรอกเสร็จหรือยัง"
-- ack_status คือ "ผอ.กลุ่มเห็นแล้วหรือยัง" คนละมิติกัน บันทึกหนึ่งเป็น final ได้โดยยังไม่ถูกรับทราบ

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_approve_nithet boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.profiles.can_approve_nithet IS
  'สิทธิ์รับทราบบันทึกการนิเทศ (ผอ.กลุ่มนิเทศ) + ให้ข้อเสนอแนะ — แยกจาก can_manage_nithet_plan';

ALTER TABLE public.nithet_visits
  ADD COLUMN IF NOT EXISTS ack_status      text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS acknowledged_by uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS acknowledged_at timestamptz,
  ADD COLUMN IF NOT EXISTS ack_note        text NOT NULL DEFAULT '';

ALTER TABLE public.nithet_visits
  DROP CONSTRAINT IF EXISTS nithet_visits_ack_status_chk;
ALTER TABLE public.nithet_visits
  ADD CONSTRAINT nithet_visits_ack_status_chk CHECK (ack_status IN ('pending','acknowledged'));

COMMENT ON COLUMN public.nithet_visits.ack_status IS
  'pending/acknowledged — เปลี่ยนได้ทางเดียวผ่าน RPC acknowledge_nithet_visit เท่านั้น (ล็อกไว้ที่ trigger)';

-- ── ล็อกฟิลด์รับทราบใน trigger เดิมของ nithet_visits (migration 0075) ──
-- ต้อง CREATE OR REPLACE ทับฟังก์ชันเดิมทั้งก้อน เพราะ Postgres ไม่มี "ALTER FUNCTION ADD BODY"
CREATE OR REPLACE FUNCTION public.nithet_visits_before_insert()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;

  -- เจ้าของบันทึกคือคนที่ล็อกอินอยู่เสมอ สวมชื่อคนอื่นไม่ได้
  IF auth.uid() IS NOT NULL THEN NEW.created_by := auth.uid(); END IF;

  -- ร่างห้ามหลุดออกหน้าเว็บสาธารณะ
  IF NEW.status = 'draft' THEN NEW.is_public := false; END IF;

  IF NEW.followup_required AND NEW.followup_status = 'none' THEN
    NEW.followup_status := 'open';
  END IF;

  -- บันทึกใหม่ต้องเริ่มที่ pending เสมอ ไม่มีใครสร้างบันทึกที่รับทราบไปแล้วได้ตั้งแต่ insert
  NEW.ack_status      := 'pending';
  NEW.acknowledged_by := NULL;
  NEW.acknowledged_at := NULL;
  NEW.ack_note        := '';
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.nithet_visits_before_update()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;

  -- โอนเจ้าของบันทึกไม่ได้
  NEW.created_by := OLD.created_by;

  IF NEW.status = 'draft' THEN NEW.is_public := false; END IF;

  IF NEW.followup_required AND NEW.followup_status = 'none' THEN
    NEW.followup_status := 'open';
  END IF;

  -- แก้ฟิลด์รับทราบตรง ๆ ไม่ได้ ต้องผ่าน RPC acknowledge_nithet_visit (SECURITY DEFINER)
  -- เท่านั้น — current_user ตอนถูกเรียกผ่าน RPC จะไม่ใช่ authenticated/anon แล้วจึงข้ามมาถึงตรงนี้ไม่ได้
  NEW.ack_status      := OLD.ack_status;
  NEW.acknowledged_by := OLD.acknowledged_by;
  NEW.acknowledged_at := OLD.acknowledged_at;
  NEW.ack_note        := OLD.ack_note;
  RETURN NEW;
END;
$$;

-- ── RPC รับทราบ ─────────────────────────────────────────────
-- pattern เดียวกับ review_award() ใน 20240101000063_awards.sql — เช็คสิทธิ์เองแยกจาก RLS/trigger
CREATE OR REPLACE FUNCTION public.acknowledge_nithet_visit(p_id uuid, p_note text DEFAULT '')
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  allowed boolean;
BEGIN
  SELECT (p.role IN ('super_admin','admin') OR p.can_approve_nithet)
    INTO allowed FROM public.profiles p WHERE p.id = auth.uid();

  IF NOT COALESCE(allowed, false) THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์รับทราบบันทึกการนิเทศ';
  END IF;

  UPDATE public.nithet_visits
    SET ack_status = 'acknowledged',
        acknowledged_by = auth.uid(),
        acknowledged_at = now(),
        ack_note = COALESCE(p_note, '')
    WHERE id = p_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.acknowledge_nithet_visit(uuid, text) TO authenticated;

NOTIFY pgrst, 'reload schema';
