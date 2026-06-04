-- ─── Supervision System ───────────────────────────────────────────────────────
-- Tables: supervision_forms, supervision_questions, supervision_responses, supervision_answers

-- ─── supervision_forms ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.supervision_forms (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title          text        NOT NULL,
  description    text,
  created_by     uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  status         text        NOT NULL DEFAULT 'draft'
                             CHECK (status IN ('draft','published','closed')),
  target         text        NOT NULL DEFAULT 'all'
                             CHECK (target IN ('all','selected')),
  target_schools uuid[]      DEFAULT '{}',
  deadline       timestamptz,
  allow_public   boolean     NOT NULL DEFAULT false,
  public_token   text        UNIQUE DEFAULT gen_random_uuid()::text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.supervision_forms ENABLE ROW LEVEL SECURITY;

-- ผู้ใช้ที่ login ทุกคนอ่านได้
CREATE POLICY "supervision_forms: authenticated read"
  ON public.supervision_forms FOR SELECT
  USING (auth.role() = 'authenticated');

-- admin/supervisor/staff เท่านั้นสร้าง/แก้ไข/ลบ
CREATE POLICY "supervision_forms: staff write"
  ON public.supervision_forms FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

CREATE POLICY "supervision_forms: staff update"
  ON public.supervision_forms FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

CREATE POLICY "supervision_forms: staff delete"
  ON public.supervision_forms FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- anon สามารถอ่านฟอร์มที่ allow_public=true ผ่าน token (ต้องใช้ RPC)
-- ─── supervision_questions ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.supervision_questions (
  id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id       uuid    NOT NULL REFERENCES public.supervision_forms(id) ON DELETE CASCADE,
  sort_order    int     NOT NULL DEFAULT 0,
  question_text text    NOT NULL,
  description   text,
  type          text    NOT NULL DEFAULT 'text'
                        CHECK (type IN ('text','textarea','choice','multi_choice','rating','yes_no','number')),
  options       jsonb   NOT NULL DEFAULT '[]',
  required      boolean NOT NULL DEFAULT true,
  settings      jsonb   NOT NULL DEFAULT '{}'
);

ALTER TABLE public.supervision_questions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "supervision_questions: authenticated read"
  ON public.supervision_questions FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "supervision_questions: staff write"
  ON public.supervision_questions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

CREATE POLICY "supervision_questions: staff update"
  ON public.supervision_questions FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

CREATE POLICY "supervision_questions: staff delete"
  ON public.supervision_questions FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- ─── supervision_responses ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.supervision_responses (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id       uuid        NOT NULL REFERENCES public.supervision_forms(id) ON DELETE CASCADE,
  school_id     uuid        REFERENCES public.schools(id) ON DELETE SET NULL,
  school_name   text,
  submitted_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  submitted_at  timestamptz NOT NULL DEFAULT now(),
  is_complete   boolean     NOT NULL DEFAULT false,
  session_token text        UNIQUE
);

ALTER TABLE public.supervision_responses ENABLE ROW LEVEL SECURITY;

-- admin/supervisor/staff อ่านได้ทั้งหมด
CREATE POLICY "supervision_responses: staff read"
  ON public.supervision_responses FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- school/teacher อ่านได้เฉพาะของตัวเอง
CREATE POLICY "supervision_responses: school read own"
  ON public.supervision_responses FOR SELECT
  USING (
    submitted_by = auth.uid()
    OR (
      school_id IS NOT NULL
      AND school_id IN (
        SELECT school_id FROM public.profiles WHERE id = auth.uid()
      )
    )
  );

-- ทุก authenticated user INSERT ได้ (school กรอกแบบ)
CREATE POLICY "supervision_responses: authenticated insert"
  ON public.supervision_responses FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- อัปเดตได้เฉพาะ owner หรือ staff
CREATE POLICY "supervision_responses: owner update"
  ON public.supervision_responses FOR UPDATE
  USING (
    submitted_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- ─── supervision_answers ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.supervision_answers (
  id          uuid  PRIMARY KEY DEFAULT gen_random_uuid(),
  response_id uuid  NOT NULL REFERENCES public.supervision_responses(id) ON DELETE CASCADE,
  question_id uuid  NOT NULL REFERENCES public.supervision_questions(id) ON DELETE CASCADE,
  answer      jsonb
);

ALTER TABLE public.supervision_answers ENABLE ROW LEVEL SECURITY;

-- staff อ่านได้ทั้งหมด
CREATE POLICY "supervision_answers: staff read"
  ON public.supervision_answers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- owner อ่านได้เฉพาะตัวเอง
CREATE POLICY "supervision_answers: owner read"
  ON public.supervision_answers FOR SELECT
  USING (
    response_id IN (
      SELECT id FROM public.supervision_responses WHERE submitted_by = auth.uid()
    )
  );

-- ทุก authenticated INSERT ได้
CREATE POLICY "supervision_answers: authenticated insert"
  ON public.supervision_answers FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- owner หรือ staff แก้ไขได้
CREATE POLICY "supervision_answers: owner update"
  ON public.supervision_answers FOR UPDATE
  USING (
    response_id IN (
      SELECT id FROM public.supervision_responses WHERE submitted_by = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- ─── RPC: get_supervision_form_public ─────────────────────────────────────────
-- ให้ anon user (ลิงค์สาธารณะ) โหลดฟอร์มได้โดยไม่ต้อง auth
CREATE OR REPLACE FUNCTION public.get_supervision_form_public(p_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_form  jsonb;
  v_qs    jsonb;
BEGIN
  SELECT to_jsonb(f) INTO v_form
  FROM public.supervision_forms f
  WHERE f.public_token = p_token
    AND f.allow_public = true
    AND f.status = 'published';

  IF v_form IS NULL THEN RETURN NULL; END IF;

  SELECT jsonb_agg(to_jsonb(q) ORDER BY q.sort_order) INTO v_qs
  FROM public.supervision_questions q
  WHERE q.form_id = (v_form->>'id')::uuid;

  RETURN v_form || jsonb_build_object('questions', COALESCE(v_qs, '[]'::jsonb));
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_supervision_form_public(text) TO anon, authenticated;

-- ─── RPC: submit_supervision_public ──────────────────────────────────────────
-- ให้ anon user ส่งคำตอบได้ผ่าน token (ไม่ต้อง login)
CREATE OR REPLACE FUNCTION public.submit_supervision_public(
  p_token       text,
  p_school_id   uuid,
  p_school_name text,
  p_answers     jsonb  -- [{question_id, answer}]
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

  -- ป้องกันส่งซ้ำ (same school + form)
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
    INSERT INTO public.supervision_answers (response_id, question_id, answer)
    VALUES (
      v_resp_id,
      (v_ans->>'question_id')::uuid,
      v_ans->'answer'
    );
  END LOOP;

  RETURN jsonb_build_object('response_id', v_resp_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_supervision_public(text, uuid, text, jsonb) TO anon, authenticated;

-- ─── Indexes ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_supervision_questions_form    ON public.supervision_questions(form_id);
CREATE INDEX IF NOT EXISTS idx_supervision_responses_form    ON public.supervision_responses(form_id);
CREATE INDEX IF NOT EXISTS idx_supervision_responses_school  ON public.supervision_responses(school_id);
CREATE INDEX IF NOT EXISTS idx_supervision_answers_response  ON public.supervision_answers(response_id);
