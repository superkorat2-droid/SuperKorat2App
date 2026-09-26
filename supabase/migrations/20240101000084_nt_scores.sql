-- Migration 84: ระบบผลคะแนน NT/O-NET/RT รายปี (นำเข้าจากรายงาน "Local 03" ของ สทศ./สพฐ.)
-- เก็บคะแนนเป็น jsonb ยืดหยุ่นตามวิชา เพื่อรองรับ NT (2 วิชา), O-NET (4 วิชา), RT (2 สมรรถนะ)
-- โดยไม่ต้องแก้ schema — ตอนนี้ implement เฉพาะ parser ของไฟล์ NT ป.3 เท่านั้น

CREATE TABLE public.nt_periods (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_type     text NOT NULL CHECK (exam_type IN ('NT','ONET','RT')),
  grade_level   text NOT NULL,               -- 'ป.3', 'ป.6', 'ม.3', 'ม.6', 'ป.1'
  academic_year int  NOT NULL,               -- ปีการศึกษา พ.ศ. เช่น 2566
  title         text NOT NULL DEFAULT '',
  subjects      jsonb NOT NULL DEFAULT '[]', -- [{"key":"math","label":"ด้านคณิตศาสตร์"}, ...]
  is_archived   boolean NOT NULL DEFAULT false,
  show_public   boolean NOT NULL DEFAULT false, -- เผื่ออนาคต ยังไม่มี UI/RPC สาธารณะรอบนี้
  archived_at   timestamptz,
  created_by    uuid REFERENCES public.profiles(id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (exam_type, grade_level, academic_year)
);

CREATE TABLE public.nt_school_scores (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id    uuid NOT NULL REFERENCES public.nt_periods(id) ON DELETE CASCADE,
  school_id    uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  scores       jsonb NOT NULL,               -- {"math":{"score":36.4,"pct":36.4,"level":"พอใช้"}, "thai":{...}, "overall":{...}}
  raw          jsonb NOT NULL DEFAULT '{}',  -- แถวดิบจากไฟล์ (ลำดับ, ขนาดโรงเรียน, อำเภอ ฯลฯ)
  uploaded_at  timestamptz NOT NULL DEFAULT now(),
  uploaded_by  uuid REFERENCES public.profiles(id),
  UNIQUE (period_id, school_id)
);

-- ค่าเฉลี่ยอ้างอิงระดับจังหวัด/ประเทศ — กรอกเองเพราะไฟล์ Local03 ไม่มีตัวเลขนี้
CREATE TABLE public.nt_benchmarks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_id   uuid NOT NULL REFERENCES public.nt_periods(id) ON DELETE CASCADE,
  scope       text NOT NULL CHECK (scope IN ('province','national')),
  scores      jsonb NOT NULL,               -- {"math":{"pct":..}, "thai":{"pct":..}, "overall":{"pct":..}}
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (period_id, scope)
);

CREATE INDEX ON public.nt_school_scores (period_id);
CREATE INDEX ON public.nt_school_scores (school_id);
CREATE INDEX ON public.nt_benchmarks (period_id);

-- ── updated_at trigger (reuse ฟังก์ชันที่มีอยู่แล้ว) ──────────────────────────
CREATE TRIGGER nt_periods_updated_at
  BEFORE UPDATE ON public.nt_periods
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER nt_benchmarks_updated_at
  BEFORE UPDATE ON public.nt_benchmarks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE public.nt_periods       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nt_school_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nt_benchmarks    ENABLE ROW LEVEL SECURITY;

-- อ่านได้: บุคลากรเขต (ไม่ผูกกับโรงเรียนเจ้าของข้อมูล — ข้อมูลมาจากไฟล์เขตทั้งก้อนเสมอ)
CREATE POLICY "nt_periods select" ON public.nt_periods
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );
CREATE POLICY "nt_periods admin all" ON public.nt_periods
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin') AND is_approved = true)
  );

CREATE POLICY "nt_school_scores select" ON public.nt_school_scores
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );
CREATE POLICY "nt_school_scores admin all" ON public.nt_school_scores
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin') AND is_approved = true)
  );

CREATE POLICY "nt_benchmarks select" ON public.nt_benchmarks
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );
CREATE POLICY "nt_benchmarks admin all" ON public.nt_benchmarks
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin') AND is_approved = true)
  );
