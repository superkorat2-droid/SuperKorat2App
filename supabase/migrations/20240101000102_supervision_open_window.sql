-- Migration 102: แบบนิเทศ — วันที่เริ่มทำได้ (open_at) + วันหมดเขตส่ง (deadline) ปิดรับอัตโนมัติ
--
-- 1) open_at ใหม่ (null = เปิดรับทันที) · deadline เดิม = วันหมดเขตส่ง (null = ไม่มีหมดเขต)
-- 2) แก้เวลาคลาด 7 ชม.: หน้าแก้ไขเดิมส่ง datetime-local ("2026-11-10T14:29") ไม่มีโซนเวลา
--    ฐานข้อมูลตีความเป็น UTC → เก็บเป็น 21:29 เวลาไทย ทั้งที่ผู้สร้างพิมพ์ 14:29
--    ตีความเวลาที่เก็บไว้ใหม่ให้เป็นเวลาไทย — ทำในบล็อกเดียวกับการเพิ่ม open_at
--    (open_at มีอยู่แล้ว = เคยรันแล้ว → ไม่เลื่อนซ้ำ)
--    หน้าเว็บตั้งแต่ migration นี้ส่งเวลาพร้อมโซนเวลา (useSupervisionWindow.js)
-- 3) ฟังก์ชันส่งแบบปฏิเสธเมื่อยังไม่ถึง open_at ('not_open') หรือเลย deadline ('closed')
--    นิยามลอกจาก migration 100/101 (ตรงกับ production) ต่างแค่ส่วนที่ระบุ
-- รันซ้ำได้

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'supervision_forms' AND column_name = 'open_at'
  ) THEN
    ALTER TABLE public.supervision_forms ADD COLUMN open_at timestamptz;
    UPDATE public.supervision_forms
      SET deadline = (deadline AT TIME ZONE 'UTC') AT TIME ZONE 'Asia/Bangkok'
      WHERE deadline IS NOT NULL;
  END IF;
END $$;

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
  v_open_at         timestamptz;
  v_deadline        timestamptz;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;

  SELECT p.school_id, s.name
  INTO v_school_id, v_school_name
  FROM public.profiles p
  LEFT JOIN public.schools s ON s.id = p.school_id
  WHERE p.id = v_uid;

  SELECT respondent_type, target, target_schools, open_at, deadline
  INTO v_respondent_type, v_target, v_target_schools, v_open_at, v_deadline
  FROM public.supervision_forms
  WHERE id = p_form_id AND status = 'published';

  IF v_respondent_type IS NULL THEN
    RETURN jsonb_build_object('error', 'form_not_found');
  END IF;

  -- ช่วงเวลารับคำตอบ (migration 102)
  IF v_open_at IS NOT NULL AND v_open_at > now() THEN
    RETURN jsonb_build_object('error', 'not_open', 'open_at', v_open_at);
  END IF;
  IF v_deadline IS NOT NULL AND v_deadline < now() THEN
    RETURN jsonb_build_object('error', 'closed', 'deadline', v_deadline);
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
  v_open_at         timestamptz;
  v_deadline        timestamptz;
BEGIN
  SELECT id, respondent_type, target, target_schools, open_at, deadline
  INTO v_form_id, v_respondent_type, v_target, v_target_schools, v_open_at, v_deadline
  FROM public.supervision_forms
  WHERE public_token = p_token AND allow_public = true AND status = 'published';

  IF v_form_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Form not found or not public');
  END IF;

  -- ช่วงเวลารับคำตอบ (migration 102)
  IF v_open_at IS NOT NULL AND v_open_at > now() THEN
    RETURN jsonb_build_object('error', 'not_open', 'open_at', v_open_at);
  END IF;
  IF v_deadline IS NOT NULL AND v_deadline < now() THEN
    RETURN jsonb_build_object('error', 'closed', 'deadline', v_deadline);
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

-- เพิ่มคีย์ open_at (การเรียงเหมือน migration 101)
CREATE OR REPLACE FUNCTION public.get_supervision_list_public()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_forms jsonb;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',               f.id,
      'title',            f.title,
      'description',      f.description,
      'deadline',         f.deadline,
      'open_at',          f.open_at,
      'allow_public',     f.allow_public,
      'public_token',     f.public_token,
      'respondent_type',  f.respondent_type,
      'status_visibility',f.status_visibility,
      'target',           f.target,
      'response_count',   (
        SELECT COUNT(*) FROM public.supervision_responses r
        WHERE r.form_id = f.id AND r.is_complete = true
      ),
      'target_count', (
        SELECT COUNT(*)::int FROM public.schools s
        WHERE (f.target = 'all' OR s.id = ANY(f.target_schools))
          AND (s.is_active OR EXISTS (
            SELECT 1 FROM public.supervision_responses r
            WHERE r.form_id = f.id AND r.school_id = s.id AND r.is_complete = true
          ))
      )
    )
    -- ยังไม่จัด (home_order null) ขึ้นก่อน → แล้วตามลำดับที่แอดมินจัด → สำรองด้วยกำหนดส่งใกล้สุด/สร้างล่าสุด
    ORDER BY (f.home_order IS NOT NULL), f.home_order ASC, f.deadline ASC NULLS LAST, f.created_at DESC
  ) INTO v_forms
  FROM public.supervision_forms f
  WHERE f.status = 'published' AND f.show_on_home = true;

  RETURN COALESCE(v_forms, '[]'::jsonb);
END;
$function$;
