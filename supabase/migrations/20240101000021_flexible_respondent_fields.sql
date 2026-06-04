-- Migration 21: flexible respondent fields (show/required per field)

-- อัปเดต DEFAULT เป็น object array แบบใหม่
ALTER TABLE public.supervision_forms
  ALTER COLUMN respondent_fields SET DEFAULT '[
    {"key":"name",      "label":"ชื่อ-นามสกุล",    "show":true,  "required":true},
    {"key":"position",  "label":"ตำแหน่ง/วิทยฐานะ","show":true,  "required":true},
    {"key":"school",    "label":"โรงเรียน",          "show":false, "required":false},
    {"key":"gender",    "label":"เพศ",               "show":false, "required":false},
    {"key":"age_range", "label":"ช่วงอายุ",          "show":false, "required":false},
    {"key":"phone",     "label":"เบอร์โทรศัพท์",     "show":false, "required":false},
    {"key":"email",     "label":"อีเมล",             "show":false, "required":false}
  ]'::jsonb;

-- Migrate existing individual forms จาก string array → object array
UPDATE public.supervision_forms
SET respondent_fields = '[
  {"key":"name",      "label":"ชื่อ-นามสกุล",    "show":true,  "required":true},
  {"key":"position",  "label":"ตำแหน่ง/วิทยฐานะ","show":true,  "required":true},
  {"key":"school",    "label":"โรงเรียน",          "show":false, "required":false},
  {"key":"gender",    "label":"เพศ",               "show":false, "required":false},
  {"key":"age_range", "label":"ช่วงอายุ",          "show":false, "required":false},
  {"key":"phone",     "label":"เบอร์โทรศัพท์",     "show":false, "required":false},
  {"key":"email",     "label":"อีเมล",             "show":false, "required":false}
]'::jsonb
WHERE respondent_type = 'individual';

-- อัปเดต submit_supervision_authenticated ให้รับ respondent_info
DROP FUNCTION IF EXISTS public.submit_supervision_authenticated(uuid, jsonb);

CREATE OR REPLACE FUNCTION public.submit_supervision_authenticated(
  p_form_id         uuid,
  p_answers         jsonb,
  p_respondent_info jsonb DEFAULT NULL
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

  -- dedup เฉพาะ school mode
  IF v_respondent_type = 'school' AND EXISTS (
    SELECT 1 FROM public.supervision_responses
    WHERE form_id = p_form_id AND school_id = v_school_id AND is_complete = true
  ) THEN
    RETURN jsonb_build_object('error', 'already_submitted');
  END IF;

  INSERT INTO public.supervision_responses
    (form_id, school_id, school_name, submitted_by, is_complete, respondent_info)
  VALUES (p_form_id, v_school_id, v_school_name, v_uid, true, p_respondent_info)
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

GRANT EXECUTE ON FUNCTION public.submit_supervision_authenticated(uuid, jsonb, jsonb)
  TO authenticated;
