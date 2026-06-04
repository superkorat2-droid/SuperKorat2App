-- Migration 26: DMC Student Information System (summary-only, no individual data)

-- ── dmc_periods: admin กำหนดรอบการเก็บข้อมูล ─────────────────────────────
CREATE TABLE public.dmc_periods (
  id            uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  academic_year text    NOT NULL,
  semester      int     NOT NULL CHECK (semester IN (1, 2)),
  title         text    NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  is_archived   boolean NOT NULL DEFAULT false,
  show_public   boolean NOT NULL DEFAULT false,
  visibility    jsonb   NOT NULL DEFAULT '{
    "total": true, "by_grade": true, "gender": true,
    "bmi": false, "disadvantaged": false,
    "guardian_relation": false, "parent_jobs": false,
    "religion": false, "nationality": false
  }',
  deadline      timestamptz,
  archived_at   timestamptz,
  created_by    uuid REFERENCES public.profiles(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── dmc_school_uploads: โรงเรียนส่งข้อมูล (ทับเดิมถ้าส่งซ้ำ) ─────────────
CREATE TABLE public.dmc_school_uploads (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id    uuid NOT NULL REFERENCES public.dmc_periods(id) ON DELETE CASCADE,
  school_id    uuid NOT NULL REFERENCES public.schools(id),
  total        int  NOT NULL,
  summary      jsonb NOT NULL,
  uploaded_at  timestamptz NOT NULL DEFAULT now(),
  uploaded_by  uuid REFERENCES public.profiles(id),
  UNIQUE(period_id, school_id)
);

CREATE INDEX ON public.dmc_school_uploads (period_id);
CREATE INDEX ON public.dmc_school_uploads (school_id);

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.dmc_periods      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dmc_school_uploads ENABLE ROW LEVEL SECURITY;

-- dmc_periods: admin จัดการ | authenticated อ่าน active | public อ่าน archived+public
CREATE POLICY "dmc_periods select"
  ON public.dmc_periods FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
            AND role IN ('super_admin','admin','supervisor','staff'))
    OR (is_active = true  AND auth.role() = 'authenticated')
    OR (show_public = true AND is_archived = true)
  );

CREATE POLICY "dmc_periods admin write"
  ON public.dmc_periods FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
                 AND role IN ('super_admin','admin')));

-- dmc_school_uploads: school จัดการของตน | admin เห็นทั้งหมด
CREATE POLICY "dmc_uploads all"
  ON public.dmc_school_uploads FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
            AND role IN ('super_admin','admin'))
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.school_id = dmc_school_uploads.school_id
    )
  );

-- ── Public RPC: สถิตินักเรียนสาธารณะ ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_dmc_public_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_period  public.dmc_periods%ROWTYPE;
  v_uploads jsonb;
  v_total   int;
BEGIN
  SELECT * INTO v_period
  FROM public.dmc_periods
  WHERE is_archived = true AND show_public = true
  ORDER BY academic_year DESC, semester DESC LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'no_public_data');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'school_id',   u.school_id,
      'school_name', s.name,
      'total',       u.total,
      'summary',     u.summary,
      'uploaded_at', u.uploaded_at
    ) ORDER BY s.name
  ),
  COUNT(*)::int
  INTO v_uploads, v_total
  FROM public.dmc_school_uploads u
  JOIN public.schools s ON s.id = u.school_id
  WHERE u.period_id = v_period.id;

  RETURN jsonb_build_object(
    'period',        to_jsonb(v_period),
    'uploads',       COALESCE(v_uploads, '[]'::jsonb),
    'total_schools', COALESCE(v_total, 0),
    'visibility',    v_period.visibility
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_dmc_public_stats() TO anon, authenticated;
