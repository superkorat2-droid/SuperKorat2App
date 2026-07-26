-- ═══════════════════════════════════════════════════════════════════════
-- work_submissions — รับผลงานจาก "บุคคลภายนอกเขต" โดยไม่ต้องมีบัญชี
--
-- ทำไมต้องแยกตาราง ไม่ให้ anon เขียนลง works ตรงๆ:
--   1. works.owner_id เป็น NOT NULL — คนนอกไม่มีบัญชี ไม่มี uuid จะใส่
--   2. เปิด INSERT ให้ anon บนตารางที่หน้าสาธารณะอ่านอยู่ = ซ้ำรอยช่องโหว่
--      คลังสื่อที่เพิ่งอุดใน 0059 (policy FOR ALL ที่ไม่มี WITH CHECK)
--   3. แยกแล้ว anon เขียนได้ที่เดียว อ่านกลับไม่ได้ แตะของที่เผยแพร่แล้วไม่ได้
--
-- เมื่ออนุมัติ → RPC คัดลอกไปสร้างแถวใน works ให้ โดย owner_id = ผู้อนุมัติ
-- (เพราะ FK ต้องชี้ profiles จริง) แต่เครดิตบนหน้าเว็บใช้ submitter_name/org
--
-- แนวคิดหลัก: ผูกกับ "หนังสือนำส่ง" ที่เขตลงทะเบียนรับไว้จริง เพื่อให้ ศน.
-- เปิดทะเบียนรับหนังสือมาเทียบได้ ไม่ต้องเชื่อคำกรอกของคนนอก
-- ตกลงกับ user: หนังสือนำส่ง "ไม่บังคับกรอก แต่เตือน" และไม่ส่งอีเมลแจ้งผล
-- (ใช้การโทร/ตอบหนังสือกลับตามระบบราชการปกติ)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.work_submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- ผู้ส่ง (บังคับ)
  submitter_name     text NOT NULL,
  submitter_position text,
  submitter_org      text NOT NULL,          -- สังกัด/หน่วยงาน (คนละเขตก็พิมพ์ได้อิสระ)
  submitter_email    text NOT NULL,
  submitter_phone    text,

  -- หนังสือนำส่ง (ไม่บังคับ แต่ฟอร์มเตือนว่าอาจอนุมัติล่าช้า/ไม่ผ่าน)
  letter_url  text,
  letter_no   text,
  letter_date date,

  -- ผลงาน
  title         text NOT NULL,
  description   text,
  work_type     text NOT NULL DEFAULT 'other',
  work_url      text NOT NULL,               -- ลิงก์สาธารณะของผลงาน
  cover_url     text,
  subject_group text,
  grade_levels  text[],
  academic_year text,

  -- การตรวจสอบ
  status          text NOT NULL DEFAULT 'pending',
  letter_verified boolean NOT NULL DEFAULT false,  -- ศน. ติ๊กว่าเทียบทะเบียนรับหนังสือแล้ว
  reviewed_by     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at     timestamptz,
  reject_reason   text DEFAULT '',
  work_id         uuid REFERENCES public.works(id) ON DELETE SET NULL, -- แถวที่สร้างเมื่ออนุมัติ

  created_at timestamptz DEFAULT now(),

  CONSTRAINT work_submissions_status_chk CHECK (status IN ('pending','approved','rejected'))
);

CREATE INDEX IF NOT EXISTS idx_work_submissions_status  ON public.work_submissions(status, created_at DESC);
-- กันยิงซ้ำเนื้อหาเดิมจากอีเมลเดิม (สแปมแบบง่ายๆ)
CREATE UNIQUE INDEX IF NOT EXISTS uq_work_submissions_dup
  ON public.work_submissions(lower(submitter_email), lower(title));

ALTER TABLE public.work_submissions ENABLE ROW LEVEL SECURITY;

-- ── RLS ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "work_submissions: anon insert" ON public.work_submissions;
DROP POLICY IF EXISTS "work_submissions: reviewer read" ON public.work_submissions;
DROP POLICY IF EXISTS "work_submissions: reviewer update" ON public.work_submissions;
DROP POLICY IF EXISTS "work_submissions: admin delete" ON public.work_submissions;

-- ใครก็ส่งได้ แต่บังคับ status='pending' และห้ามตั้งค่าฟิลด์ฝ่ายตรวจสอบเอง
-- (WITH CHECK เท่านั้นไม่พอ — trigger ข้างล่างล้างค่าให้อีกชั้น)
CREATE POLICY "work_submissions: anon insert" ON public.work_submissions
  FOR INSERT TO anon, authenticated
  WITH CHECK (
    status = 'pending'
    AND letter_verified = false
    AND reviewed_by IS NULL
    AND work_id IS NULL
    AND length(trim(submitter_name))  BETWEEN 2 AND 200
    AND length(trim(submitter_org))   BETWEEN 2 AND 300
    AND submitter_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'
    AND length(trim(title))           BETWEEN 3 AND 500
    AND work_url ~* '^https?://'
    AND (letter_url IS NULL OR letter_url ~* '^https?://')
  );

-- อ่าน/ตรวจ ได้เฉพาะ ศน. ขึ้นไป — anon เขียนแล้วอ่านกลับไม่ได้
CREATE POLICY "work_submissions: reviewer read" ON public.work_submissions
  FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin','supervisor')
  ));

CREATE POLICY "work_submissions: reviewer update" ON public.work_submissions
  FOR UPDATE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin','supervisor')
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin','supervisor')
  ));

CREATE POLICY "work_submissions: admin delete" ON public.work_submissions
  FOR DELETE TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin')
  ));

-- ── trigger: ไม่เชื่อค่าที่ client ส่งมาสำหรับฟิลด์ฝ่ายตรวจสอบ ──────────
-- SECURITY INVOKER + current_user เพื่อให้ service_role/หลังบ้านข้ามได้
-- (บทเรียนจาก 0058: SECURITY DEFINER ที่มี SET clause สร้าง GUC scope แยก
--  ทำให้ set_config ไม่ทะลุถึง trigger — ใช้ current_user แทน)
CREATE OR REPLACE FUNCTION public.work_submissions_before_insert()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;
  NEW.status          := 'pending';
  NEW.letter_verified := false;
  NEW.reviewed_by     := NULL;
  NEW.reviewed_at     := NULL;
  NEW.reject_reason   := '';
  NEW.work_id         := NULL;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_work_submissions_before_insert ON public.work_submissions;
CREATE TRIGGER trg_work_submissions_before_insert
  BEFORE INSERT ON public.work_submissions
  FOR EACH ROW EXECUTE FUNCTION public.work_submissions_before_insert();

-- ── RPC: ตรวจ/อนุมัติ — อนุมัติแล้วสร้างแถวใน works ให้ ────────────────
CREATE OR REPLACE FUNCTION public.review_work_submission(
  p_id uuid,
  p_status text,
  p_reason text DEFAULT '',
  p_letter_verified boolean DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_role text;
  v_sub  public.work_submissions;
  v_work_id uuid;
BEGIN
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'สถานะไม่ถูกต้อง';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role IS NULL OR v_role NOT IN ('super_admin','admin','supervisor') THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์ตรวจผลงานจากภายนอก';
  END IF;

  SELECT * INTO v_sub FROM public.work_submissions WHERE id = p_id;
  IF v_sub.id IS NULL THEN RAISE EXCEPTION 'ไม่พบรายการที่ส่งเข้ามา'; END IF;

  -- แค่ติ๊ก/ยกเลิกติ๊ก "ตรวจหนังสือแล้ว" โดยยังไม่ตัดสิน
  IF p_status = 'pending' THEN
    UPDATE public.work_submissions
      SET letter_verified = COALESCE(p_letter_verified, letter_verified),
          status = 'pending', reviewed_by = NULL, reviewed_at = NULL, reject_reason = ''
      WHERE id = p_id;
    RETURN jsonb_build_object('ok', true, 'status', 'pending');
  END IF;

  IF p_status = 'approved' THEN
    -- บังคับให้ยืนยันหนังสือก่อน กันเผลอกดอนุมัติของที่ยังไม่ได้เทียบทะเบียนรับ
    IF NOT COALESCE(p_letter_verified, v_sub.letter_verified) THEN
      RAISE EXCEPTION 'ต้องยืนยันว่าตรวจกับทะเบียนรับหนังสือแล้วก่อนอนุมัติ';
    END IF;

    IF v_sub.work_id IS NOT NULL THEN
      v_work_id := v_sub.work_id;          -- อนุมัติซ้ำ — ไม่สร้างแถวใหม่
    ELSE
      -- owner_id ต้องชี้ profiles จริง จึงใช้ผู้อนุมัติ
      -- เครดิตผู้สร้างผลงานจริงเก็บใน school_name (หน้าสาธารณะแสดงช่องนี้อยู่แล้ว)
      INSERT INTO public.works (
        owner_id, owner_type, work_type, title, description,
        subject_group, grade_levels, academic_year,
        file_url, cover_url, school_name, tags
      ) VALUES (
        auth.uid(), 'teacher', v_sub.work_type, v_sub.title, v_sub.description,
        -- ต้อง COALESCE: คอลัมน์เหล่านี้เป็น NOT NULL ที่มี default แต่การส่ง NULL
        -- ตรงๆ จะข้าม default ไปชน NOT NULL (ฟอร์มภายนอกส่ง null มาเมื่อไม่ได้กรอก)
        COALESCE(v_sub.subject_group, ''),
        COALESCE(v_sub.grade_levels, '{}'),
        COALESCE(v_sub.academic_year, ''),
        v_sub.work_url, v_sub.cover_url,
        trim(v_sub.submitter_name || ' · ' || v_sub.submitter_org),
        ARRAY['ผลงานภายนอกเขต']
      ) RETURNING id INTO v_work_id;
    END IF;

    UPDATE public.work_submissions
      SET status = 'approved', letter_verified = true, work_id = v_work_id,
          reviewed_by = auth.uid(), reviewed_at = now(), reject_reason = ''
      WHERE id = p_id;

    RETURN jsonb_build_object('ok', true, 'status', 'approved', 'work_id', v_work_id);
  END IF;

  -- rejected
  UPDATE public.work_submissions
    SET status = 'rejected', reject_reason = COALESCE(p_reason,''),
        reviewed_by = auth.uid(), reviewed_at = now(),
        letter_verified = COALESCE(p_letter_verified, letter_verified)
    WHERE id = p_id;

  RETURN jsonb_build_object('ok', true, 'status', 'rejected');
END;
$$;

GRANT EXECUTE ON FUNCTION public.review_work_submission(uuid, text, text, boolean) TO authenticated;

-- ── toggle เปิด/ปิดรับผลงานจากภายนอก (ปิดได้ทันทีถ้าถูกถล่ม) ──────────
ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS allow_external_works boolean DEFAULT true;

NOTIFY pgrst, 'reload schema';
