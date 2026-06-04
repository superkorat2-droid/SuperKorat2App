-- Migration 20: individual respondent mode + login-required fill

-- ── supervision_forms: เพิ่ม respondent mode ──────────────────────────────────
ALTER TABLE public.supervision_forms
  ADD COLUMN IF NOT EXISTS respondent_type   text    NOT NULL DEFAULT 'school'
    CHECK (respondent_type IN ('school','individual')),
  ADD COLUMN IF NOT EXISTS respondent_fields jsonb   NOT NULL DEFAULT '["name","position"]';

-- ── supervision_responses: เก็บข้อมูลผู้ตอบ (สำหรับ individual mode) ──────────
ALTER TABLE public.supervision_responses
  ADD COLUMN IF NOT EXISTS respondent_info jsonb;

-- ── ลบ RPC เดิมแล้วสร้างใหม่รองรับ respondent_info ──────────────────────────
DROP FUNCTION IF EXISTS public.submit_supervision_public(text, uuid, text, jsonb);

CREATE OR REPLACE FUNCTION public.submit_supervision_public(
  p_token           text,
  p_school_id       uuid,
  p_school_name     text,
  p_answers         jsonb,
  p_respondent_info jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_form_id         uuid;
  v_respondent_type text;
  v_resp_id         uuid;
  v_ans             jsonb;
BEGIN
  SELECT id, respondent_type INTO v_form_id, v_respondent_type
  FROM public.supervision_forms
  WHERE public_token = p_token AND allow_public = true AND status = 'published';

  IF v_form_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Form not found or not public');
  END IF;

  -- ป้องกันส่งซ้ำเฉพาะ school mode
  IF v_respondent_type = 'school' AND p_school_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.supervision_responses
    WHERE form_id = v_form_id AND school_id = p_school_id AND is_complete = true
  ) THEN
    RETURN jsonb_build_object('error', 'already_submitted');
  END IF;

  INSERT INTO public.supervision_responses
    (form_id, school_id, school_name, is_complete, respondent_info)
  VALUES (v_form_id, p_school_id, p_school_name, true, p_respondent_info)
  RETURNING id INTO v_resp_id;

  FOR v_ans IN SELECT * FROM jsonb_array_elements(p_answers) LOOP
    INSERT INTO public.supervision_answers
      (response_id, question_id, answer, evidence_file_url, evidence_link_url)
    VALUES (
      v_resp_id,
      (v_ans->>'question_id')::uuid,
      v_ans->'answer',
      NULLIF(v_ans->>'evidence_file_url', ''),
      NULLIF(v_ans->>'evidence_link_url', '')
    );
  END LOOP;

  RETURN jsonb_build_object('response_id', v_resp_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_supervision_public(text, uuid, text, jsonb, jsonb)
  TO anon, authenticated;

-- ── RPC: กรอกแบบผ่าน login (school portal) ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_supervision_authenticated(
  p_form_id uuid,
  p_answers jsonb
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_uid             uuid := auth.uid();
  v_school_id       uuid;
  v_school_name     text;
  v_respondent_type text;
  v_target          text;
  v_target_schools  uuid[];
  v_resp_id         uuid;
  v_ans             jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  SELECT p.school_id, s.name
  INTO v_school_id, v_school_name
  FROM public.profiles p
  LEFT JOIN public.schools s ON s.id = p.school_id
  WHERE p.id = v_uid;

  SELECT respondent_type, target, target_schools
  INTO v_respondent_type, v_target, v_target_schools
  FROM public.supervision_forms
  WHERE id = p_form_id AND status = 'published';

  IF v_respondent_type IS NULL THEN
    RETURN jsonb_build_object('error', 'form_not_found');
  END IF;

  IF v_target = 'selected' AND NOT (v_school_id = ANY(v_target_schools)) THEN
    RETURN jsonb_build_object('error', 'not_assigned');
  END IF;

  -- ป้องกันส่งซ้ำเฉพาะ school mode
  IF v_respondent_type = 'school' AND EXISTS (
    SELECT 1 FROM public.supervision_responses
    WHERE form_id = p_form_id AND school_id = v_school_id AND is_complete = true
  ) THEN
    RETURN jsonb_build_object('error', 'already_submitted');
  END IF;

  INSERT INTO public.supervision_responses
    (form_id, school_id, school_name, submitted_by, is_complete)
  VALUES (p_form_id, v_school_id, v_school_name, v_uid, true)
  RETURNING id INTO v_resp_id;

  FOR v_ans IN SELECT * FROM jsonb_array_elements(p_answers) LOOP
    INSERT INTO public.supervision_answers
      (response_id, question_id, answer, evidence_file_url, evidence_link_url)
    VALUES (
      v_resp_id,
      (v_ans->>'question_id')::uuid,
      v_ans->'answer',
      NULLIF(v_ans->>'evidence_file_url', ''),
      NULLIF(v_ans->>'evidence_link_url', '')
    );
  END LOOP;

  RETURN jsonb_build_object('response_id', v_resp_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_supervision_authenticated(uuid, jsonb)
  TO authenticated;
