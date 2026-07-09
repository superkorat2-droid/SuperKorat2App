-- submit_supervision_public เดิมไม่เคยตรวจ target/target_schools เลย (ต่างจาก
-- submit_supervision_authenticated ที่ตรวจอยู่แล้ว) — โรงเรียนที่ไม่ได้ถูกเลือกเป้าหมาย
-- ยังส่งผ่านลิงค์สาธารณะได้ ตอนนี้แก้ให้ตรวจเหมือนกันทั้งสองทาง
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
  v_target          text;
  v_target_schools  uuid[];
  v_resp_id         uuid;
  v_ans             jsonb;
BEGIN
  SELECT id, respondent_type, target, target_schools
  INTO v_form_id, v_respondent_type, v_target, v_target_schools
  FROM public.supervision_forms
  WHERE public_token = p_token AND allow_public = true AND status = 'published';

  IF v_form_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Form not found or not public');
  END IF;

  IF v_target = 'selected' AND p_school_id IS NOT NULL AND NOT (p_school_id = ANY(v_target_schools)) THEN
    RETURN jsonb_build_object('error', 'not_assigned');
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
