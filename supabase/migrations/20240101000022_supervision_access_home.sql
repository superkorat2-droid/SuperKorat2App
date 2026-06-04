-- Migration 22: access control + home section for supervision

-- ── profiles: สิทธิ์เผยแพร่แบบนิเทศ ──────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_publish_supervision boolean NOT NULL DEFAULT false;

-- ── supervision_forms: home section settings ──────────────────────────────────
ALTER TABLE public.supervision_forms
  ADD COLUMN IF NOT EXISTS show_on_home      boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS status_visibility text    NOT NULL DEFAULT 'hidden'
    CHECK (status_visibility IN ('hidden','authenticated','public'));

-- ── อัปเดต RLS supervision_forms ─────────────────────────────────────────────
DROP POLICY IF EXISTS "supervision_forms: authenticated read" ON public.supervision_forms;
DROP POLICY IF EXISTS "supervision_forms: staff write"        ON public.supervision_forms;
DROP POLICY IF EXISTS "supervision_forms: staff update"       ON public.supervision_forms;
DROP POLICY IF EXISTS "supervision_forms: staff delete"       ON public.supervision_forms;

-- SELECT: admin=ทั้งหมด | ตนเอง | published (authenticated)
CREATE POLICY "supervision_forms: select"
  ON public.supervision_forms FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR created_by = auth.uid()
    OR (status = 'published' AND auth.role() = 'authenticated')
  );

-- INSERT: supervisor/staff เท่านั้น, created_by = self
CREATE POLICY "supervision_forms: insert"
  ON public.supervision_forms FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- UPDATE: admin=ทั้งหมด | เจ้าของ
CREATE POLICY "supervision_forms: update"
  ON public.supervision_forms FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR (created_by = auth.uid() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid()
      AND role IN ('supervisor','staff')
    ))
  );

-- DELETE: admin=ทั้งหมด | เจ้าของ
CREATE POLICY "supervision_forms: delete"
  ON public.supervision_forms FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR (created_by = auth.uid() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid()
      AND role IN ('supervisor','staff')
    ))
  );

-- ── RPC: รายการแบบนิเทศสำหรับหน้าแรก ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_supervision_list_public()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_forms jsonb;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',               f.id,
      'title',            f.title,
      'description',      f.description,
      'deadline',         f.deadline,
      'allow_public',     f.allow_public,
      'public_token',     f.public_token,
      'respondent_type',  f.respondent_type,
      'status_visibility',f.status_visibility,
      'target',           f.target,
      'response_count',   (
        SELECT COUNT(*) FROM public.supervision_responses r
        WHERE r.form_id = f.id AND r.is_complete = true
      ),
      'target_count', CASE
        WHEN f.target = 'all' THEN (SELECT COUNT(*) FROM public.schools)::int
        ELSE COALESCE(array_length(f.target_schools, 1), 0)
      END
    )
    -- เรียงตาม deadline ใกล้สุดก่อน (null/ไม่มี deadline อยู่ท้าย)
    ORDER BY f.deadline ASC NULLS LAST, f.created_at DESC
  ) INTO v_forms
  FROM public.supervision_forms f
  WHERE f.status = 'published' AND f.show_on_home = true;

  RETURN COALESCE(v_forms, '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_supervision_list_public() TO anon, authenticated;

-- ── RPC: สถานะโรงเรียนต่อแบบนิเทศ ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_supervision_status_public(p_form_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_visibility text;
  v_target     text;
  v_target_sch uuid[];
  v_responded  jsonb;
  v_pending    jsonb;
  v_total      int := 0;
BEGIN
  SELECT status_visibility, target, target_schools
  INTO v_visibility, v_target, v_target_sch
  FROM public.supervision_forms
  WHERE id = p_form_id AND status = 'published';

  IF v_visibility IS NULL OR v_visibility = 'hidden' THEN
    RETURN jsonb_build_object('error', 'not_accessible');
  END IF;

  SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) ORDER BY s.name)
  INTO v_responded
  FROM public.supervision_responses sr
  JOIN public.schools s ON s.id = sr.school_id
  WHERE sr.form_id = p_form_id AND sr.is_complete = true AND sr.school_id IS NOT NULL;

  IF v_target = 'all' THEN
    SELECT COUNT(*) INTO v_total FROM public.schools;
    SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) ORDER BY s.name)
    INTO v_pending
    FROM public.schools s
    WHERE s.id NOT IN (
      SELECT COALESCE(sr.school_id, '00000000-0000-0000-0000-000000000000')
      FROM public.supervision_responses sr
      WHERE sr.form_id = p_form_id AND sr.is_complete = true AND sr.school_id IS NOT NULL
    );
  ELSE
    v_total := COALESCE(array_length(v_target_sch, 1), 0);
    SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) ORDER BY s.name)
    INTO v_pending
    FROM public.schools s
    WHERE s.id = ANY(v_target_sch)
    AND s.id NOT IN (
      SELECT COALESCE(sr.school_id, '00000000-0000-0000-0000-000000000000')
      FROM public.supervision_responses sr
      WHERE sr.form_id = p_form_id AND sr.is_complete = true AND sr.school_id IS NOT NULL
    );
  END IF;

  RETURN jsonb_build_object(
    'total',             v_total,
    'responded',         COALESCE(jsonb_array_length(v_responded), 0),
    'responded_schools', COALESCE(v_responded, '[]'::jsonb),
    'pending_schools',   COALESCE(v_pending,   '[]'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_supervision_status_public(uuid) TO anon, authenticated;
