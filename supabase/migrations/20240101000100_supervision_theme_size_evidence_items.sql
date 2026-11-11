-- Migration 100: แบบนิเทศ — ธีมสี + ขนาดการแสดงผล + รายการเอกสารหลักฐานที่ผู้ตอบเลือก
-- เพิ่มอย่างเดียว ไม่แตะข้อมูลเดิม: แบบเดิมได้ theme='site' (สีเว็บ) และ display_size='normal' หน้าตาเหมือนเดิม
-- รายการเอกสารที่ "ผู้สร้าง" กำหนด เก็บใน supervision_questions.settings.evidence_items (jsonb เดิม ไม่ต้องเพิ่มคอลัมน์)
-- รันซ้ำได้ปลอดภัย

-- ─── 1) ธีมสี + ขนาด ───────────────────────────────────────────────────────
-- get_supervision_form_public ใช้ to_jsonb(f) → ส่งไปหน้าสาธารณะเองโดยไม่ต้องแก้ RPC
-- รายชื่อธีมต้องตรงกับ SUPERVISION_THEMES ใน src/composables/useSupervisionTheme.js
ALTER TABLE public.supervision_forms
  ADD COLUMN IF NOT EXISTS theme        text NOT NULL DEFAULT 'site',
  ADD COLUMN IF NOT EXISTS display_size text NOT NULL DEFAULT 'normal';

DO $$ BEGIN
  ALTER TABLE public.supervision_forms ADD CONSTRAINT supervision_forms_theme_check
    CHECK (theme IN ('site','ocean','emerald','violet','rose','sunset','gold','slate'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE public.supervision_forms ADD CONSTRAINT supervision_forms_display_size_check
    CHECK (display_size IN ('normal','large','xlarge'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ─── 2) รายการเอกสารหลักฐานที่ผู้ตอบติ๊ก/พิมพ์เอง ─────────────────────────────
ALTER TABLE public.supervision_answers
  ADD COLUMN IF NOT EXISTS evidence_items jsonb;

-- ─── 3) ฟังก์ชันส่งแบบ: เก็บ evidence_items เพิ่ม ─────────────────────────────
-- นิยามนี้ลอกจาก production (pg_get_functiondef, 11 พ.ย. 69) ทุกบรรทัด ต่างแค่ insert evidence_items เพิ่ม
-- โค้ดเก่าที่ไม่ส่งคีย์นี้ → null ไม่พัง
CREATE OR REPLACE FUNCTION public.submit_supervision_authenticated(p_form_id uuid, p_answers jsonb, p_respondent_info jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
      (response_id, question_id, answer, evidence_file_url, evidence_link_url, evidence_items)
    VALUES (
      v_resp_id,
      (v_ans->>'question_id')::uuid,
      v_ans->'answer',
      NULLIF(v_ans->>'evidence_file_url', ''),
      NULLIF(v_ans->>'evidence_link_url', ''),
      CASE WHEN jsonb_typeof(v_ans->'evidence_items') = 'array'
            AND jsonb_array_length(v_ans->'evidence_items') > 0
           THEN v_ans->'evidence_items' END
    );
  END LOOP;

  RETURN jsonb_build_object('response_id', v_resp_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.submit_supervision_public(p_token text, p_school_id uuid, p_school_name text, p_answers jsonb, p_respondent_info jsonb DEFAULT NULL::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
      (response_id, question_id, answer, evidence_file_url, evidence_link_url, evidence_items)
    VALUES (
      v_resp_id,
      (v_ans->>'question_id')::uuid,
      v_ans->'answer',
      NULLIF(v_ans->>'evidence_file_url', ''),
      NULLIF(v_ans->>'evidence_link_url', ''),
      CASE WHEN jsonb_typeof(v_ans->'evidence_items') = 'array'
            AND jsonb_array_length(v_ans->'evidence_items') > 0
           THEN v_ans->'evidence_items' END
    );
  END LOOP;

  RETURN jsonb_build_object('response_id', v_resp_id);
END;
$function$;
