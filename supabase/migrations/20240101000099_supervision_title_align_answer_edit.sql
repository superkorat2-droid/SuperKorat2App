-- Migration 99: แบบนิเทศ — ตำแหน่งชื่อแบบในหน้าปก + ผู้จัดการแก้คำตอบได้ + ปิดช่องเขียนคำตอบตรง
-- เป็นการเพิ่มอย่างเดียว ไม่แตะข้อมูลเดิม (แบบเดิมได้ title_align = 'center' หน้าตาเหมือนเดิม)
-- รันซ้ำได้ปลอดภัย

-- ─── 1) ตำแหน่งชื่อแบบในหน้าปก ─────────────────────────────────────────────
-- get_supervision_form_public ใช้ to_jsonb(f) → คอลัมน์ใหม่ส่งไปหน้าสาธารณะเองโดยไม่ต้องแก้ RPC
ALTER TABLE public.supervision_forms
  ADD COLUMN IF NOT EXISTS title_align text NOT NULL DEFAULT 'center';

DO $$ BEGIN
  ALTER TABLE public.supervision_forms
    ADD CONSTRAINT supervision_forms_title_align_check CHECK (title_align IN ('left','center'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ─── 2) ร่องรอยการแก้คำตอบโดยผู้จัดการ ─────────────────────────────────────
ALTER TABLE public.supervision_responses
  ADD COLUMN IF NOT EXISTS edited_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS edited_at timestamptz;

-- ─── 3) ใคร "จัดการ" แบบนิเทศนี้ได้ ─────────────────────────────────────────
-- แอดมิน / ผู้สร้างแบบ / ผู้รับผิดชอบรายบุคคล (responsible_ids)
-- ไม่นับ responsible_group: แบบเก็บ key กลุ่ม แต่ profiles.department เก็บชื่อกลุ่ม จับคู่ไม่ได้แน่นอน
CREATE OR REPLACE FUNCTION public.can_manage_supervision_form(p_form_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
      OR EXISTS (SELECT 1 FROM public.supervision_forms f
                 WHERE f.id = p_form_id
                   AND (f.created_by = auth.uid() OR auth.uid() = ANY (f.responsible_ids)));
$$;

REVOKE ALL ON FUNCTION public.can_manage_supervision_form(uuid) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.can_manage_supervision_form(uuid) TO authenticated;

-- ─── 4) สิทธิ์เขียน คำตอบ/ชุดคำตอบ ────────────────────────────────────────
-- การส่งแบบทุกช่องทางผ่าน submit_supervision_public / submit_supervision_authenticated (SECURITY DEFINER)
-- ไม่พึ่ง policy เหล่านี้ → ปิดได้โดยผู้ตอบยังส่งได้ปกติ
-- เดิม: ผู้ล็อกอินทุกคน (รวมบัญชีโรงเรียน) insert คำตอบ/ชุดคำตอบเข้าแบบไหนก็ได้ และ staff ทุกคนแก้ได้ทุกแบบ
DROP POLICY IF EXISTS "supervision_answers: authenticated insert" ON public.supervision_answers;
DROP POLICY IF EXISTS "supervision_answers: owner update"         ON public.supervision_answers;
DROP POLICY IF EXISTS "supervision_answers: manager insert"       ON public.supervision_answers;
DROP POLICY IF EXISTS "supervision_answers: manager update"       ON public.supervision_answers;

CREATE POLICY "supervision_answers: manager insert" ON public.supervision_answers
  FOR INSERT TO authenticated
  WITH CHECK (EXISTS (SELECT 1 FROM public.supervision_responses r
                      WHERE r.id = response_id AND public.can_manage_supervision_form(r.form_id)));

CREATE POLICY "supervision_answers: manager update" ON public.supervision_answers
  FOR UPDATE TO authenticated
  USING      (EXISTS (SELECT 1 FROM public.supervision_responses r
                      WHERE r.id = response_id AND public.can_manage_supervision_form(r.form_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM public.supervision_responses r
                      WHERE r.id = response_id AND public.can_manage_supervision_form(r.form_id)));

DROP POLICY IF EXISTS "supervision_responses: authenticated insert" ON public.supervision_responses;
DROP POLICY IF EXISTS "supervision_responses: owner update"         ON public.supervision_responses;
DROP POLICY IF EXISTS "supervision_responses: manager update"       ON public.supervision_responses;

CREATE POLICY "supervision_responses: manager update" ON public.supervision_responses
  FOR UPDATE TO authenticated
  USING      (public.can_manage_supervision_form(form_id))
  WITH CHECK (public.can_manage_supervision_form(form_id));
