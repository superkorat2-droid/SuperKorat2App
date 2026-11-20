-- Migration 104: แบบสำรวจเครือข่ายวิชาชีพครู + ทำเนียบครู (ทั้งเขต ~2,000 คน)
--
-- ครูส่วนใหญ่ไม่มีบัญชีในระบบ → ตอบแบบไม่ล็อกอินผ่าน RPC (SECURITY DEFINER)
--   * เบอร์โทร = ตัวกันซ้ำ (คนละเบอร์ = คนละคน)
--   * ส่งสำเร็จได้ "ลิงก์แก้ไขส่วนตัว" (token สุ่ม 192 บิต) — เก็บแค่ sha256 ในตารางแยก
--     ที่ไม่มี policy ใด ๆ (ศน./แอดมินก็อ่าน hash ไม่ได้)
--   * ทำลิงก์หาย → ศน./แอดมินออกลิงก์ใหม่ให้ (teacher_reissue_edit_token)
--
-- ความเป็นส่วนตัว (แนวเดียวกับ 0092 สมุดโทรศัพท์ผู้บริหาร)
--   * anon อ่านตาราง teachers ตรงไม่ได้ — หน้าสาธารณะผ่าน public_teacher_directory()
--     ที่คืนเฉพาะ ชื่อ รูป โรงเรียน อำเภอ/ศูนย์ ชั้นที่สอน เครือข่าย
--   * เบอร์ ไลน์ อีเมล วุฒิ คำตอบส่วนที่ 2 → เฉพาะ super_admin/admin/supervisor/staff
--
-- ทุกคอลัมน์ตัวเลือกเก็บเป็น KEY ไม่เก็บ label (บทเรียนชื่อกลุ่มงานหลุดกัน 0073)
-- label อยู่ใน teacher_survey_config.options ซึ่งแอดมินแก้ได้เองโดยข้อมูลเดิมไม่เพี้ยน
--
-- อำเภอ/ศูนย์เครือข่าย ไม่เก็บซ้ำ — ดึงจาก schools.district / school_group ผ่าน school_id
-- school_id ใช้ ON DELETE SET NULL (ห้าม CASCADE — บทเรียนโรงเรียนปิด/ยุบ 0088)

-- ═══════════════════════════════════════════════════════════════════
-- 1) ตั้งค่าแบบสำรวจ (แถวเดียว)
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.teacher_survey_config (
  id              int PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  title           text NOT NULL DEFAULT 'การขับเคลื่อนระบบฐานข้อมูลพัฒนาเครือข่ายวิชาชีพครู',
  intro           text,
  is_open         boolean NOT NULL DEFAULT true,
  open_at         timestamptz,
  deadline        timestamptz,
  options         jsonb NOT NULL DEFAULT '{}'::jsonb,
  limits          jsonb NOT NULL DEFAULT '{}'::jsonb,
  extra_questions jsonb NOT NULL DEFAULT '[]'::jsonb,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

DROP TRIGGER IF EXISTS trg_teacher_survey_config_updated ON public.teacher_survey_config;
CREATE TRIGGER trg_teacher_survey_config_updated
  BEFORE UPDATE ON public.teacher_survey_config
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.teacher_survey_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teacher_survey_config: read" ON public.teacher_survey_config;
CREATE POLICY "teacher_survey_config: read" ON public.teacher_survey_config
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS "teacher_survey_config: admin write" ON public.teacher_survey_config;
CREATE POLICY "teacher_survey_config: admin write" ON public.teacher_survey_config
  FOR UPDATE TO authenticated
  USING (public.get_my_role() IN ('super_admin', 'admin'))
  WITH CHECK (public.get_my_role() IN ('super_admin', 'admin'));

GRANT SELECT ON public.teacher_survey_config TO anon, authenticated;
GRANT UPDATE ON public.teacher_survey_config TO authenticated;

-- ค่าเริ่มต้นตามแบบสำรวจ PDF (ข้อ 5, 7, 8, 9, 10, 11)
INSERT INTO public.teacher_survey_config (id, intro, options, limits)
VALUES (1,
  'แบบสำรวจนี้จัดทำขึ้นเพื่อปรับปรุงระบบฐานข้อมูลพื้นฐาน บริบทการสอน สภาพปัญหา และความต้องการในการพัฒนาตนเองของข้าราชการครูและบุคลากรทางการศึกษา เพื่อนำมาออกแบบและขับเคลื่อน "เครือข่ายวิชาชีพครู" ในรูปแบบเครือข่ายความร่วมมือที่คล่องตัว เน้นการเป็นเพื่อนคู่คิด แบ่งปันสื่อการเรียนรู้ และช่วยลดภาระงานครู (ไม่ใช่การจัดตั้งชมรมหรือเพิ่มภาระงานเอกสาร) ข้อมูลของท่านจะนำไปใช้ประโยชน์ในการวางแผนส่งเสริมและสนับสนุนทางวิชาการให้ตรงตามบริบทและความต้องการของครูอย่างแท้จริง',
  $json${
    "grades": [
      {"key":"k",  "label":"ปฐมวัย"},
      {"key":"p1", "label":"ประถมศึกษาปีที่ 1"},
      {"key":"p2", "label":"ประถมศึกษาปีที่ 2"},
      {"key":"p3", "label":"ประถมศึกษาปีที่ 3"},
      {"key":"p4", "label":"ประถมศึกษาปีที่ 4"},
      {"key":"p5", "label":"ประถมศึกษาปีที่ 5"},
      {"key":"p6", "label":"ประถมศึกษาปีที่ 6"},
      {"key":"m1", "label":"มัธยมศึกษาปีที่ 1"},
      {"key":"m2", "label":"มัธยมศึกษาปีที่ 2"},
      {"key":"m3", "label":"มัธยมศึกษาปีที่ 3"}
    ],
    "ranks": [
      {"key":"assistant", "label":"ครูผู้ช่วย"},
      {"key":"teacher",   "label":"ครู (ยังไม่มีวิทยฐานะ)"},
      {"key":"cs2",       "label":"ครูชำนาญการ (คศ.2)"},
      {"key":"cs3",       "label":"ครูชำนาญการพิเศษ (คศ.3)"},
      {"key":"cs4",       "label":"ครูเชี่ยวชาญ (คศ.4)"},
      {"key":"contract",  "label":"พนักงานราชการ / ครูอัตราจ้าง"}
    ],
    "major_match": [
      {"key":"match",    "label":"สอนตรงตามสาขาวิชาเอกที่สำเร็จการศึกษา"},
      {"key":"partial",  "label":"สอนตรงสาขาวิชาเอกบางส่วน และรับผิดชอบสอนวิชาอื่นร่วมด้วย"},
      {"key":"mismatch", "label":"สอนไม่ตรงตามสาขาวิชาเอกที่สำเร็จการศึกษา"}
    ],
    "networks": [
      {"key":"early",    "label":"เครือข่ายครูปฐมวัย"},
      {"key":"thai",     "label":"เครือข่ายครูภาษาไทย"},
      {"key":"math",     "label":"เครือข่ายครูคณิตศาสตร์"},
      {"key":"science",  "label":"เครือข่ายครูวิทยาศาสตร์"},
      {"key":"computer", "label":"เครือข่ายครูเทคโนโลยีคอมพิวเตอร์"},
      {"key":"dance",    "label":"เครือข่ายครูนาฏศิลป์"},
      {"key":"music",    "label":"เครือข่ายครูดนตรี"},
      {"key":"art",      "label":"เครือข่ายครูศิลปะ"},
      {"key":"career",   "label":"เครือข่ายครูการงานอาชีพ"},
      {"key":"social",   "label":"เครือข่ายครูสังคมศึกษา ศาสนาและวัฒนธรรม และประวัติศาสตร์"},
      {"key":"foreign",  "label":"เครือข่ายครูภาษาต่างประเทศ", "children": [
        {"key":"english",    "label":"เครือข่ายครูภาษาอังกฤษ"},
        {"key":"chinese",    "label":"เครือข่ายครูภาษาจีน"},
        {"key":"lang_other", "label":"เครือข่ายครูภาษาอื่น ๆ", "is_other": true}
      ]}
    ],
    "constraints": [
      {"key":"materials",    "label":"ขาดแคลนวัสดุอุปกรณ์ สื่อการสอน เครื่องดนตรี อุปกรณ์วิทยาศาสตร์ หรือคอมพิวเตอร์"},
      {"key":"internet",     "label":"มีข้อจำกัดด้านสัญญาณอินเทอร์เน็ต หรืออุปกรณ์ดิจิทัลของผู้เรียน"},
      {"key":"budget",       "label":"มีข้อจำกัดด้านงบประมาณในการจัดซื้อสื่อและจัดกิจกรรมพัฒนาผู้เรียน"},
      {"key":"small_school", "label":"เป็นโรงเรียนขนาดเล็กที่มีครูไม่ครบชั้น (ต้องสอนควบชั้น หรือสอนหลายรายวิชา)"},
      {"key":"no_peer",      "label":"ไม่มีเพื่อนร่วมวิชาชีพในกลุ่มสาระเดียวกันภายในโรงเรียนเพื่อปรึกษาหารือ"},
      {"key":"other",        "label":"อื่น ๆ", "is_other": true}
    ],
    "topics": [
      {"key":"active_learning", "label":"การออกแบบการจัดการเรียนรู้เชิงรุก (Active Learning) ตามธรรมชาติของรายวิชา"},
      {"key":"ai_digital",      "label":"การประยุกต์ใช้ AI และเทคโนโลยีดิจิทัลในการออกแบบการสอนและสร้างสื่อ"},
      {"key":"national_test",   "label":"เทคนิคการออกแบบข้อสอบและการจัดการเรียนรู้เพื่อยกระดับผลประเมินระดับชาติ (RT / NT / O-NET) และ PISA"},
      {"key":"authentic",       "label":"การวัดและประเมินผลตามสภาพจริง (Authentic Assessment) และการประเมินสมรรถนะผู้เรียน"},
      {"key":"classroom",       "label":"เทคนิคการจัดการชั้นเรียนและการสร้างแรงจูงใจในการเรียนรู้"},
      {"key":"integrated",      "label":"การออกแบบการเรียนรู้เชิงบูรณาการข้ามกลุ่มสาระ (เช่น STEAM Education, หน่วยการเรียนรู้บูรณาการ)"},
      {"key":"achievement",     "label":"การแก้ปัญหาผลสัมฤทธิ์ทางการเรียน / ทักษะการคิดวิเคราะห์ / ทักษะปฏิบัติของผู้เรียน"},
      {"key":"pa_rank",         "label":"แนวทางการจัดทำข้อตกลงในการพัฒนางาน (PA) และการขอมี/เลื่อนวิทยฐานะให้สอดคล้องกับการสอน"},
      {"key":"other",           "label":"อื่น ๆ", "is_other": true}
    ]
  }$json$::jsonb,
  '{"networks": 2, "topics": 3}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════
-- 2) ทะเบียนครู
-- ═══════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.teachers (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  prefix            text NOT NULL,
  first_name        text NOT NULL,
  last_name         text NOT NULL,
  school_id         uuid REFERENCES public.schools(id) ON DELETE SET NULL,
  phone             text NOT NULL UNIQUE CHECK (phone ~ '^0[0-9]{8,9}$'),
  line_id           text,
  email             text,
  grades            text[] NOT NULL DEFAULT '{}',
  degree_ba         text,
  degree_ma         text,
  degree_phd        text,
  academic_rank     text,
  major_match       text,
  networks          text[] NOT NULL DEFAULT '{}',
  networks_other    text,
  constraints       text[] NOT NULL DEFAULT '{}',
  constraints_other text,
  topics            text[] NOT NULL DEFAULT '{}',
  topics_other      text,
  suggestion        text,
  extra             jsonb NOT NULL DEFAULT '{}'::jsonb,
  photo_url         text,
  is_hidden         boolean NOT NULL DEFAULT false,
  submitted_at      timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teachers_school   ON public.teachers (school_id);
CREATE INDEX IF NOT EXISTS idx_teachers_networks ON public.teachers USING gin (networks);
CREATE INDEX IF NOT EXISTS idx_teachers_topics   ON public.teachers USING gin (topics);

DROP TRIGGER IF EXISTS trg_teachers_updated ON public.teachers;
CREATE TRIGGER trg_teachers_updated
  BEFORE UPDATE ON public.teachers
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.teachers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "teachers: staff read" ON public.teachers;
CREATE POLICY "teachers: staff read" ON public.teachers
  FOR SELECT TO authenticated
  USING (public.get_my_role() IN ('super_admin', 'admin', 'supervisor', 'staff'));

DROP POLICY IF EXISTS "teachers: admin update" ON public.teachers;
CREATE POLICY "teachers: admin update" ON public.teachers
  FOR UPDATE TO authenticated
  USING (public.get_my_role() IN ('super_admin', 'admin'))
  WITH CHECK (public.get_my_role() IN ('super_admin', 'admin'));

DROP POLICY IF EXISTS "teachers: admin delete" ON public.teachers;
CREATE POLICY "teachers: admin delete" ON public.teachers
  FOR DELETE TO authenticated
  USING (public.get_my_role() IN ('super_admin', 'admin'));

-- ไม่มี INSERT policy — เพิ่มได้ทาง teacher_survey_submit() เท่านั้น
REVOKE ALL ON public.teachers FROM anon;
GRANT SELECT, UPDATE, DELETE ON public.teachers TO authenticated;

-- hash ของลิงก์แก้ไข — แยกตาราง ไม่มี policy = ไม่มีใครอ่านผ่าน API ได้เลย
CREATE TABLE IF NOT EXISTS public.teacher_edit_tokens (
  teacher_id  uuid PRIMARY KEY REFERENCES public.teachers(id) ON DELETE CASCADE,
  token_hash  text NOT NULL UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.teacher_edit_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.teacher_edit_tokens FROM anon, authenticated;

-- นับครั้งที่ส่งต่อเครื่อง (hash ของ IP+UA) กันสคริปต์ยิงรัว
CREATE TABLE IF NOT EXISTS public.teacher_survey_hits (
  hit_hash text NOT NULL,
  hit_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_teacher_survey_hits ON public.teacher_survey_hits (hit_hash, hit_at);
ALTER TABLE public.teacher_survey_hits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.teacher_survey_hits FROM anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 3) ตัวช่วยตรวจข้อมูล (ไม่เปิดให้ anon เรียกตรง)
-- ═══════════════════════════════════════════════════════════════════

-- key ที่ "เลือกได้จริง" ของคำถามหนึ่ง (ตัวที่มี children เป็นแค่หัวกลุ่ม เลือกตรงไม่ได้)
CREATE OR REPLACE FUNCTION public._teacher_leaf_keys(p_opts jsonb, p_only_other boolean DEFAULT false)
RETURNS text[]
LANGUAGE sql IMMUTABLE
SET search_path = public
AS $$
  WITH top AS (
    SELECT o FROM jsonb_array_elements(
      CASE WHEN jsonb_typeof(p_opts) = 'array' THEN p_opts ELSE '[]'::jsonb END) o
  ), leaves AS (
    SELECT o AS leaf FROM top
     WHERE jsonb_typeof(o->'children') IS DISTINCT FROM 'array'
        OR jsonb_array_length(o->'children') = 0
    UNION ALL
    SELECT c FROM top, jsonb_array_elements(
      CASE WHEN jsonb_typeof(o->'children') = 'array' THEN o->'children' ELSE '[]'::jsonb END) c
  )
  SELECT coalesce(array_agg(leaf->>'key'), '{}')
    FROM leaves
   WHERE leaf->>'key' IS NOT NULL
     AND (NOT p_only_other OR coalesce((leaf->>'is_other')::boolean, false));
$$;

-- ข้อความ: trim, ว่าง = NULL, ตัดความยาว
CREATE OR REPLACE FUNCTION public._teacher_txt(p jsonb, p_key text, p_max int)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT left(nullif(btrim(coalesce(p->>p_key, '')), ''), p_max);
$$;

-- ตรวจคำถามเลือกหลายข้อ — คืน array ของ key ที่สะอาด หรือ RAISE ข้อความภาษาไทย
CREATE OR REPLACE FUNCTION public._teacher_pick(
  p jsonb, p_key text, p_opts jsonb, p_max int, p_required boolean, p_label text)
RETURNS text[]
LANGUAGE plpgsql IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_arr     text[];
  v_allowed text[] := public._teacher_leaf_keys(p_opts);
BEGIN
  IF jsonb_typeof(p->p_key) = 'array' THEN
    SELECT coalesce(array_agg(DISTINCT x), '{}') INTO v_arr
      FROM jsonb_array_elements_text(p->p_key) x;
  ELSE
    v_arr := '{}';
  END IF;

  IF NOT v_arr <@ v_allowed THEN
    RAISE EXCEPTION 'ตัวเลือกในข้อ "%" ไม่ถูกต้อง กรุณารีเฟรชหน้าแล้วลองใหม่', p_label;
  END IF;
  IF p_required AND cardinality(v_arr) = 0 THEN
    RAISE EXCEPTION 'กรุณาเลือกข้อ "%" อย่างน้อย 1 ข้อ', p_label;
  END IF;
  IF p_max IS NOT NULL AND p_max > 0 AND cardinality(v_arr) > p_max THEN
    RAISE EXCEPTION 'ข้อ "%" เลือกได้ไม่เกิน % ข้อ', p_label, p_max;
  END IF;
  RETURN v_arr;
END;
$$;

-- "อื่น ๆ โปรดระบุ" — ถ้าเลือกตัว is_other ต้องกรอก ไม่เลือกให้ล้างทิ้ง
CREATE OR REPLACE FUNCTION public._teacher_other(
  p jsonb, p_key text, p_selected text[], p_opts jsonb, p_label text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_txt text := public._teacher_txt(p, p_key, 200);
BEGIN
  IF NOT (p_selected && public._teacher_leaf_keys(p_opts, true)) THEN
    RETURN NULL;
  END IF;
  IF v_txt IS NULL THEN
    RAISE EXCEPTION 'กรุณาระบุรายละเอียด "อื่น ๆ" ในข้อ "%"', p_label;
  END IF;
  RETURN v_txt;
END;
$$;

-- ตรวจ + ทำความสะอาดข้อมูลทั้งชุด → คืน jsonb ที่ใช้กับ jsonb_populate_record(teachers) ได้ตรง ๆ
CREATE OR REPLACE FUNCTION public._teacher_clean(p jsonb)
RETURNS jsonb
LANGUAGE plpgsql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  c        public.teacher_survey_config;
  o        jsonb;
  v_phone  text := regexp_replace(coalesce(p->>'phone', ''), '\D', '', 'g');
  v_email  text := lower(public._teacher_txt(p, 'email', 200));
  v_school uuid;
  v_rank   text := public._teacher_txt(p, 'academic_rank', 50);
  v_major  text := public._teacher_txt(p, 'major_match', 50);
  v_grades text[]; v_nets text[]; v_cons text[]; v_tops text[];
  v_extra  jsonb := '{}'::jsonb;
  q        jsonb;
  v_val    jsonb;
BEGIN
  SELECT * INTO c FROM public.teacher_survey_config WHERE id = 1;
  o := coalesce(c.options, '{}'::jsonb);

  IF public._teacher_txt(p, 'prefix', 50) IS NULL
     OR public._teacher_txt(p, 'first_name', 100) IS NULL
     OR public._teacher_txt(p, 'last_name', 100) IS NULL THEN
    RAISE EXCEPTION 'กรุณากรอกคำนำหน้า ชื่อ และนามสกุลให้ครบ';
  END IF;

  IF v_phone !~ '^0[0-9]{8,9}$' THEN
    RAISE EXCEPTION 'เบอร์โทรศัพท์ไม่ถูกต้อง (ตัวเลข 9-10 หลัก ขึ้นต้นด้วย 0)';
  END IF;

  IF v_email IS NOT NULL AND v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
    RAISE EXCEPTION 'รูปแบบอีเมลไม่ถูกต้อง';
  END IF;

  BEGIN
    v_school := nullif(p->>'school_id', '')::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    v_school := NULL;
  END;
  IF v_school IS NULL OR NOT EXISTS (SELECT 1 FROM public.schools WHERE id = v_school) THEN
    RAISE EXCEPTION 'กรุณาเลือกโรงเรียน';
  END IF;

  IF v_rank IS NULL OR NOT (v_rank = ANY (public._teacher_leaf_keys(o->'ranks'))) THEN
    RAISE EXCEPTION 'กรุณาเลือกวิทยฐานะปัจจุบัน';
  END IF;
  IF v_major IS NOT NULL AND NOT (v_major = ANY (public._teacher_leaf_keys(o->'major_match'))) THEN
    RAISE EXCEPTION 'ตัวเลือกลักษณะการจัดการเรียนการสอนไม่ถูกต้อง';
  END IF;

  v_grades := public._teacher_pick(p, 'grades',      o->'grades',      NULL, true,  'ระดับชั้นที่รับผิดชอบการสอน');
  v_nets   := public._teacher_pick(p, 'networks',    o->'networks',    (c.limits->>'networks')::int, true, 'เครือข่ายวิชาชีพครูที่สนใจ');
  v_cons   := public._teacher_pick(p, 'constraints', o->'constraints', NULL, false, 'สภาพความพร้อมและข้อจำกัด');
  v_tops   := public._teacher_pick(p, 'topics',      o->'topics',      (c.limits->>'topics')::int, false, 'ประเด็นที่ต้องการพัฒนา');

  -- คำถามเสริมที่แอดมินเพิ่มเอง: รับเฉพาะ key ที่ประกาศไว้ ข้อความ ≤ 1000 ตัว / array ≤ 30 ค่า
  FOR q IN SELECT * FROM jsonb_array_elements(
             CASE WHEN jsonb_typeof(c.extra_questions) = 'array' THEN c.extra_questions ELSE '[]'::jsonb END)
  LOOP
    v_val := p->'extra'->(q->>'key');
    IF v_val IS NULL OR q->>'key' IS NULL THEN CONTINUE; END IF;
    IF jsonb_typeof(v_val) = 'array' THEN
      v_extra := v_extra || jsonb_build_object(q->>'key',
        (SELECT coalesce(jsonb_agg(left(x, 200)), '[]'::jsonb)
           FROM (SELECT x FROM jsonb_array_elements_text(v_val) x LIMIT 30) s));
    ELSIF jsonb_typeof(v_val) IN ('string', 'number', 'boolean') THEN
      v_extra := v_extra || jsonb_build_object(q->>'key', left(v_val #>> '{}', 1000));
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'prefix',            public._teacher_txt(p, 'prefix', 50),
    'first_name',        public._teacher_txt(p, 'first_name', 100),
    'last_name',         public._teacher_txt(p, 'last_name', 100),
    'school_id',         v_school,
    'phone',             v_phone,
    'line_id',           public._teacher_txt(p, 'line_id', 100),
    'email',             v_email,
    'grades',            to_jsonb(v_grades),
    'degree_ba',         public._teacher_txt(p, 'degree_ba', 200),
    'degree_ma',         public._teacher_txt(p, 'degree_ma', 200),
    'degree_phd',        public._teacher_txt(p, 'degree_phd', 200),
    'academic_rank',     v_rank,
    'major_match',       v_major,
    'networks',          to_jsonb(v_nets),
    'networks_other',    public._teacher_other(p, 'networks_other', v_nets, o->'networks', 'เครือข่ายวิชาชีพครูที่สนใจ'),
    'constraints',       to_jsonb(v_cons),
    'constraints_other', public._teacher_other(p, 'constraints_other', v_cons, o->'constraints', 'สภาพความพร้อมและข้อจำกัด'),
    'topics',            to_jsonb(v_tops),
    'topics_other',      public._teacher_other(p, 'topics_other', v_tops, o->'topics', 'ประเด็นที่ต้องการพัฒนา'),
    'suggestion',        public._teacher_txt(p, 'suggestion', 2000),
    'extra',             v_extra
  );
END;
$$;

REVOKE ALL ON FUNCTION public._teacher_clean(jsonb) FROM PUBLIC, anon, authenticated;

-- token → teacher_id (NULL ถ้าไม่ตรง)
CREATE OR REPLACE FUNCTION public._teacher_by_token(p_token text)
RETURNS uuid
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT teacher_id FROM public.teacher_edit_tokens
   WHERE p_token ~ '^[0-9a-f]{48}$'
     AND token_hash = encode(digest(p_token, 'sha256'), 'hex');
$$;
REVOKE ALL ON FUNCTION public._teacher_by_token(text) FROM PUBLIC, anon, authenticated;

-- ออก token ใหม่ (แทนของเดิม) — คืนตัวจริงครั้งเดียว
CREATE OR REPLACE FUNCTION public._teacher_new_token(p_teacher uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_token text := encode(gen_random_bytes(24), 'hex');
BEGIN
  INSERT INTO public.teacher_edit_tokens (teacher_id, token_hash)
  VALUES (p_teacher, encode(digest(v_token, 'sha256'), 'hex'))
  ON CONFLICT (teacher_id) DO UPDATE
    SET token_hash = EXCLUDED.token_hash, created_at = now();
  RETURN v_token;
END;
$$;
REVOKE ALL ON FUNCTION public._teacher_new_token(uuid) FROM PUBLIC, anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 4) RPC สาธารณะ
-- ═══════════════════════════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.teacher_survey_is_open()
RETURNS boolean
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce((
    SELECT is_open
       AND (open_at  IS NULL OR now() >= open_at)
       AND (deadline IS NULL OR now() <= deadline)
      FROM public.teacher_survey_config WHERE id = 1), false);
$$;
GRANT EXECUTE ON FUNCTION public.teacher_survey_is_open() TO anon, authenticated;

-- ส่งแบบสำรวจครั้งแรก
-- คืน {ok:true, id, token} | {ok:false, error:'phone_exists'|'closed'|'rate_limited'}
-- ข้อมูลผิดรูปแบบ → RAISE ข้อความภาษาไทยให้หน้าเว็บแสดงตรง ๆ
CREATE OR REPLACE FUNCTION public.teacher_survey_submit(p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_hdr  json := nullif(current_setting('request.headers', true), '')::json;
  v_ip   text;
  v_hash text;
  v      jsonb;
  v_id   uuid;
BEGIN
  IF NOT public.teacher_survey_is_open() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'closed');
  END IF;

  v_ip := btrim(split_part(coalesce(v_hdr->>'x-forwarded-for', v_hdr->>'x-real-ip', ''), ',', 1));
  v_hash := encode(digest(v_ip || '|' || coalesce(v_hdr->>'user-agent', '') || '|sk2-teacher-salt-2569', 'sha256'), 'hex');

  -- ครูหลายคนในโรงเรียนเดียวอาจใช้ Wi-Fi เดียวกัน (IP เดียว) → เผื่อไว้ 20 ครั้ง/ชม.
  IF (SELECT count(*) FROM public.teacher_survey_hits
       WHERE hit_hash = v_hash AND hit_at > now() - interval '1 hour') >= 20 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rate_limited');
  END IF;
  DELETE FROM public.teacher_survey_hits WHERE hit_at < now() - interval '1 day';
  INSERT INTO public.teacher_survey_hits (hit_hash) VALUES (v_hash);

  v := public._teacher_clean(p_data);

  IF EXISTS (SELECT 1 FROM public.teachers WHERE phone = v->>'phone') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'phone_exists');
  END IF;

  INSERT INTO public.teachers (
    prefix, first_name, last_name, school_id, phone, line_id, email, grades,
    degree_ba, degree_ma, degree_phd, academic_rank, major_match,
    networks, networks_other, constraints, constraints_other, topics, topics_other,
    suggestion, extra)
  SELECT
    prefix, first_name, last_name, school_id, phone, line_id, email, grades,
    degree_ba, degree_ma, degree_phd, academic_rank, major_match,
    networks, networks_other, constraints, constraints_other, topics, topics_other,
    suggestion, extra
  FROM jsonb_populate_record(NULL::public.teachers, v)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('ok', true, 'id', v_id, 'token', public._teacher_new_token(v_id));
END;
$$;
GRANT EXECUTE ON FUNCTION public.teacher_survey_submit(jsonb) TO anon, authenticated;

-- เปิดลิงก์แก้ไข → ข้อมูลของตัวเองทั้งหมด (+ ชื่อโรงเรียน)
CREATE OR REPLACE FUNCTION public.teacher_survey_load(p_token text)
RETURNS jsonb
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT to_jsonb(t) || jsonb_build_object('school_name', s.name)
    FROM public.teachers t
    LEFT JOIN public.schools s ON s.id = t.school_id
   WHERE t.id = public._teacher_by_token(p_token);
$$;
GRANT EXECUTE ON FUNCTION public.teacher_survey_load(text) TO anon, authenticated;

-- แก้ไขข้อมูลตัวเอง — ทำได้ตลอด (ทำเนียบเป็นข้อมูลถาวร ไม่ผูกกับช่วงเปิดรับ)
CREATE OR REPLACE FUNCTION public.teacher_survey_update(p_token text, p_data jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id uuid := public._teacher_by_token(p_token);
  v    jsonb;
BEGIN
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_token');
  END IF;

  v := public._teacher_clean(p_data);

  IF EXISTS (SELECT 1 FROM public.teachers WHERE phone = v->>'phone' AND id <> v_id) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'phone_exists');
  END IF;

  UPDATE public.teachers t SET
    (prefix, first_name, last_name, school_id, phone, line_id, email, grades,
     degree_ba, degree_ma, degree_phd, academic_rank, major_match,
     networks, networks_other, constraints, constraints_other, topics, topics_other,
     suggestion, extra)
  = (SELECT prefix, first_name, last_name, school_id, phone, line_id, email, grades,
            degree_ba, degree_ma, degree_phd, academic_rank, major_match,
            networks, networks_other, constraints, constraints_other, topics, topics_other,
            suggestion, extra
       FROM jsonb_populate_record(NULL::public.teachers, v))
  WHERE t.id = v_id;

  RETURN jsonb_build_object('ok', true, 'id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.teacher_survey_update(text, jsonb) TO anon, authenticated;

-- บันทึก/ลบรูปโปรไฟล์ — รับเฉพาะ URL ที่หน้าตาเหมือนที่ upload.php สร้างในโฟลเดอร์ teachers
CREATE OR REPLACE FUNCTION public.teacher_survey_set_photo(p_token text, p_url text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id  uuid := public._teacher_by_token(p_token);
  v_url text := nullif(btrim(coalesce(p_url, '')), '');
BEGIN
  IF v_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_token');
  END IF;
  IF v_url IS NOT NULL
     AND v_url !~ '^https?://[^/\s]+/([^\s]*/)?uploads/teachers/teachers_[0-9]{14}_[0-9a-f]{8}\.(jpe?g|png|webp|gif)$' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_url');
  END IF;
  UPDATE public.teachers SET photo_url = v_url WHERE id = v_id;
  RETURN jsonb_build_object('ok', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.teacher_survey_set_photo(text, text) TO anon, authenticated;

-- ทำเนียบครูสาธารณะ — เฉพาะฟิลด์ที่เปิดเผยได้ แบ่งหน้าที่ server
-- p_filters: {district, school_group, school_id, network, grade, q}
CREATE OR REPLACE FUNCTION public.public_teacher_directory(
  p_filters jsonb DEFAULT '{}'::jsonb, p_limit int DEFAULT 60, p_offset int DEFAULT 0)
RETURNS jsonb
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  WITH f AS (
    SELECT nullif(p_filters->>'district', '')     AS district,
           nullif(p_filters->>'school_group', '') AS school_group,
           nullif(p_filters->>'school_id', '')    AS school_id,
           nullif(p_filters->>'network', '')      AS network,
           nullif(p_filters->>'grade', '')        AS grade,
           nullif(btrim(coalesce(p_filters->>'q', '')), '') AS q
  ), rows AS (
    SELECT t.id, t.prefix, t.first_name, t.last_name, t.photo_url, t.grades, t.networks,
           s.id AS sid, s.name AS school_name, s.district, s.school_group
      FROM public.teachers t
      JOIN public.schools s ON s.id = t.school_id, f
     WHERE NOT t.is_hidden
       AND (f.district     IS NULL OR s.district     = f.district)
       AND (f.school_group IS NULL OR s.school_group = f.school_group)
       AND (f.school_id    IS NULL OR s.id::text     = f.school_id)
       AND (f.network      IS NULL OR f.network = ANY (t.networks))
       AND (f.grade        IS NULL OR f.grade   = ANY (t.grades))
       AND (f.q IS NULL OR (t.first_name || ' ' || t.last_name || ' ' || s.name) ILIKE '%' || f.q || '%')
  )
  SELECT jsonb_build_object(
    'total', (SELECT count(*) FROM rows),
    'rows', coalesce((
      SELECT jsonb_agg(jsonb_build_object(
               'id', r.id, 'prefix', r.prefix, 'first_name', r.first_name, 'last_name', r.last_name,
               'photo_url', r.photo_url, 'grades', r.grades, 'networks', r.networks,
               'school', jsonb_build_object('id', r.sid, 'name', r.school_name,
                                            'district', r.district, 'school_group', r.school_group))
             ORDER BY r.district, r.school_group, r.school_name, r.first_name)
        FROM (SELECT * FROM rows
               ORDER BY district, school_group, school_name, first_name
               LIMIT least(greatest(coalesce(p_limit, 60), 1), 200)
               OFFSET greatest(coalesce(p_offset, 0), 0)) r
    ), '[]'::jsonb)
  );
$$;
GRANT EXECUTE ON FUNCTION public.public_teacher_directory(jsonb, int, int) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════
-- 5) RPC สำหรับ ศน./แอดมิน
-- ═══════════════════════════════════════════════════════════════════
-- ครูทำลิงก์หาย → ออกลิงก์ใหม่ (ลิงก์เก่าใช้ไม่ได้ทันที)
CREATE OR REPLACE FUNCTION public.teacher_reissue_edit_token(p_teacher uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF coalesce(public.get_my_role(), '') NOT IN ('super_admin', 'admin', 'supervisor', 'staff') THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์ออกลิงก์แก้ไข';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.teachers WHERE id = p_teacher) THEN
    RAISE EXCEPTION 'ไม่พบข้อมูลครู';
  END IF;
  RETURN public._teacher_new_token(p_teacher);
END;
$$;
REVOKE ALL ON FUNCTION public.teacher_reissue_edit_token(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.teacher_reissue_edit_token(uuid) TO authenticated;

-- Edge Function media-upload (service role) ใช้ตรวจ token ก่อนออกตั๋วอัปรูป
CREATE OR REPLACE FUNCTION public.teacher_token_valid(p_token text)
RETURNS boolean
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public._teacher_by_token(p_token) IS NOT NULL;
$$;
REVOKE ALL ON FUNCTION public.teacher_token_valid(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.teacher_token_valid(text) TO service_role;
