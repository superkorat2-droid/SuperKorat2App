-- ─── Migration 18: หลักฐานอ้างอิง per question ──────────────────────────────

-- เพิ่ม evidence_type และ evidence_required ใน supervision_questions
ALTER TABLE public.supervision_questions
  ADD COLUMN IF NOT EXISTS evidence_type     text    NOT NULL DEFAULT 'none'
    CHECK (evidence_type IN ('none','upload','url','both')),
  ADD COLUMN IF NOT EXISTS evidence_required boolean NOT NULL DEFAULT false;

-- เพิ่มที่เก็บหลักฐานใน supervision_answers
ALTER TABLE public.supervision_answers
  ADD COLUMN IF NOT EXISTS evidence_file_url text,
  ADD COLUMN IF NOT EXISTS evidence_link_url text;

-- ─── Storage bucket สำหรับไฟล์หลักฐาน ───────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'supervision-evidence',
  'supervision-evidence',
  true,
  10485760,  -- 10 MB
  ARRAY['image/jpeg','image/png','image/webp','image/heic','image/gif','application/pdf']
) ON CONFLICT (id) DO NOTHING;

-- anon + authenticated อัปโหลดได้ (ฟอร์มเป็นสาธารณะ)
CREATE POLICY "supervision evidence upload"
  ON storage.objects FOR INSERT TO anon, authenticated
  WITH CHECK (bucket_id = 'supervision-evidence');

-- ทุกคนดู/ดาวน์โหลดได้
CREATE POLICY "supervision evidence read"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'supervision-evidence');

-- ─── อัปเดต submit RPC รองรับ evidence fields ────────────────────────────────
CREATE OR REPLACE FUNCTION public.submit_supervision_public(
  p_token       text,
  p_school_id   uuid,
  p_school_name text,
  p_answers     jsonb  -- [{question_id, answer, evidence_file_url?, evidence_link_url?}]
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_form_id uuid;
  v_resp_id uuid;
  v_ans     jsonb;
BEGIN
  SELECT id INTO v_form_id
  FROM public.supervision_forms
  WHERE public_token = p_token AND allow_public = true AND status = 'published';

  IF v_form_id IS NULL THEN
    RETURN jsonb_build_object('error', 'Form not found or not public');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.supervision_responses
    WHERE form_id = v_form_id AND school_id = p_school_id AND is_complete = true
  ) THEN
    RETURN jsonb_build_object('error', 'already_submitted');
  END IF;

  INSERT INTO public.supervision_responses (form_id, school_id, school_name, is_complete)
  VALUES (v_form_id, p_school_id, p_school_name, true)
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

GRANT EXECUTE ON FUNCTION public.submit_supervision_public(text, uuid, text, jsonb)
  TO anon, authenticated;
