-- ============================================================
-- patch_students.sql
-- ตาราง students + enrollment_stats + RLS + RPC
-- ============================================================

-- ── 1. students (รายชื่อนักเรียนปัจจุบัน) ────────────────────
CREATE TABLE IF NOT EXISTS public.students (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id     uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  national_id   text NOT NULL,          -- เลขบัตรประชาชน 13 หลัก (col C)
  student_code  text NOT NULL DEFAULT '', -- รหัสนักเรียน (col F)
  grade         text NOT NULL,          -- ม.1, ม.2, ป.1, ...
  room          int  NOT NULL DEFAULT 1,
  gender        text NOT NULL,          -- ช / ญ
  prefix        text NOT NULL DEFAULT '',
  first_name    text NOT NULL,
  last_name     text NOT NULL,
  birth_date    text,
  age_years     int,
  weight        numeric,
  height        numeric,
  blood_type    text,
  religion      text,
  nationality   text,
  disadvantaged text NOT NULL DEFAULT '', -- ความด้อยโอกาส / -
  academic_year text NOT NULL,          -- 2568
  term          text NOT NULL,          -- 1 / 2
  imported_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(school_id, national_id, academic_year, term)
);

CREATE INDEX IF NOT EXISTS idx_students_school    ON public.students(school_id);
CREATE INDEX IF NOT EXISTS idx_students_year_term ON public.students(academic_year, term);
CREATE INDEX IF NOT EXISTS idx_students_grade     ON public.students(grade);

-- ── 2. enrollment_stats (สถิติย้อนหลัง ไม่เก็บรายชื่อ) ───────
CREATE TABLE IF NOT EXISTS public.enrollment_stats (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id           uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  academic_year       text NOT NULL,
  term                text NOT NULL,
  count_date          date,
  total_students      int  NOT NULL DEFAULT 0,
  male_count          int  NOT NULL DEFAULT 0,
  female_count        int  NOT NULL DEFAULT 0,
  grade_stats         jsonb,  -- {"ม.1":{"total":514,"male":200,"female":314}, ...}
  health_stats        jsonb,  -- {"avg_weight":52.3,"avg_height":158.2,"underweight":12,...}
  disadvantaged_count int  NOT NULL DEFAULT 0,
  source_filename     text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE(school_id, academic_year, term)
);

CREATE INDEX IF NOT EXISTS idx_enroll_school ON public.enrollment_stats(school_id);
CREATE INDEX IF NOT EXISTS idx_enroll_year   ON public.enrollment_stats(academic_year);

-- ── 3. RLS ────────────────────────────────────────────────────
ALTER TABLE public.students        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.enrollment_stats ENABLE ROW LEVEL SECURITY;

-- students: โรงเรียน/admin/supervisor อ่านได้
DROP POLICY IF EXISTS "students_read"   ON public.students;
CREATE POLICY "students_read" ON public.students
  FOR SELECT USING (
    school_id IN (
      SELECT school_id FROM public.profiles
      WHERE id = auth.uid() AND is_approved = true
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND role IN ('super_admin','admin','supervisor')
    )
  );

-- students: โรงเรียน insert ของตัวเอง
DROP POLICY IF EXISTS "students_insert" ON public.students;
CREATE POLICY "students_insert" ON public.students
  FOR INSERT WITH CHECK (
    school_id IN (
      SELECT school_id FROM public.profiles
      WHERE id = auth.uid() AND role = 'school' AND is_approved = true
    )
  );

-- students: โรงเรียน/admin ลบได้
DROP POLICY IF EXISTS "students_delete" ON public.students;
CREATE POLICY "students_delete" ON public.students
  FOR DELETE USING (
    school_id IN (
      SELECT school_id FROM public.profiles
      WHERE id = auth.uid() AND role = 'school' AND is_approved = true
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('super_admin','admin')
    )
  );

-- enrollment_stats: เหมือนกัน
DROP POLICY IF EXISTS "enroll_read"   ON public.enrollment_stats;
CREATE POLICY "enroll_read" ON public.enrollment_stats
  FOR SELECT USING (
    school_id IN (
      SELECT school_id FROM public.profiles
      WHERE id = auth.uid() AND is_approved = true
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor')
    )
  );

DROP POLICY IF EXISTS "enroll_write" ON public.enrollment_stats;
CREATE POLICY "enroll_write" ON public.enrollment_stats
  FOR ALL USING (
    school_id IN (
      SELECT school_id FROM public.profiles
      WHERE id = auth.uid() AND role = 'school' AND is_approved = true
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('super_admin','admin')
    )
  );

-- ── 4. RPC: get_student_batches ───────────────────────────────
-- คืน list of {academic_year, term, count, imported_at} ต่อโรงเรียน
CREATE OR REPLACE FUNCTION public.get_student_batches(p_school_id uuid)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(json_agg(t ORDER BY t.academic_year DESC, t.term DESC)::jsonb, '[]'::jsonb)
  FROM (
    SELECT academic_year, term,
           COUNT(*)::int         AS count,
           MAX(imported_at)      AS imported_at
    FROM   public.students
    WHERE  school_id = p_school_id
    GROUP BY academic_year, term
  ) t;
$$;
GRANT EXECUTE ON FUNCTION public.get_student_batches(uuid) TO authenticated;

-- ── 5. RPC: get_students_admin ────────────────────────────────
-- admin ดูนักเรียนรวมทุกโรง พร้อม filter + pagination
CREATE OR REPLACE FUNCTION public.get_students_admin(
  p_school_id   uuid    DEFAULT NULL,
  p_year        text    DEFAULT NULL,
  p_term        text    DEFAULT NULL,
  p_grade       text    DEFAULT NULL,
  p_gender      text    DEFAULT NULL,
  p_dis         boolean DEFAULT NULL,
  p_limit       int     DEFAULT 100,
  p_offset      int     DEFAULT 0
)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT json_build_object(
    'total', COUNT(*) OVER(),
    'rows',  COALESCE(json_agg(r ORDER BY r.school_name, r.grade, r.room, r.last_name)::jsonb, '[]'::jsonb)
  )
  FROM (
    SELECT
      st.*,
      sc.name  AS school_name,
      sc.dmc_code
    FROM public.students st
    JOIN public.schools  sc ON sc.id = st.school_id
    WHERE (p_school_id IS NULL OR st.school_id = p_school_id)
      AND (p_year      IS NULL OR st.academic_year = p_year)
      AND (p_term      IS NULL OR st.term = p_term)
      AND (p_grade     IS NULL OR st.grade = p_grade)
      AND (p_gender    IS NULL OR st.gender = p_gender)
      AND (p_dis       IS NULL OR (p_dis = true AND st.disadvantaged <> '-' AND st.disadvantaged <> ''))
    LIMIT  p_limit
    OFFSET p_offset
  ) r;
$$;
GRANT EXECUTE ON FUNCTION public.get_students_admin(uuid,text,text,text,text,boolean,int,int) TO authenticated;

-- ── ✅ Done ───────────────────────────────────────────────────
DO $$ BEGIN
  RAISE NOTICE '✅ patch_students.sql complete';
END $$;
