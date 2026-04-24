-- ============================================================
-- Migration V2: User Roles + Area Config + Schools + Pages
-- รันใน Supabase SQL Editor
-- ============================================================

-- ── 1. AREA CONFIG ────────────────────────────────────────────
-- ตั้งค่าเขตพื้นที่ (1 row เสมอ) สำหรับ multi-branding
CREATE TABLE IF NOT EXISTS public.area_config (
  id              smallint PRIMARY KEY DEFAULT 1,
  -- ชื่อเขตพื้นที่
  area_name       text    NOT NULL DEFAULT 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
  area_name_short text    NOT NULL DEFAULT 'กลุ่มนิเทศฯ',
  area_type       text    NOT NULL DEFAULT 'สพป.',   -- สพป. | สพม. | สศศ.
  province        text    NOT NULL DEFAULT '',
  area_number     text    DEFAULT '',               -- เขต 1, เขต 2 ฯลฯ
  -- โลโก้และสี
  logo_url        text    DEFAULT '',
  primary_color   text    DEFAULT '#2563eb',
  secondary_color text    DEFAULT '#4f46e5',
  -- ข้อมูลติดต่อ
  contact_address text    DEFAULT '',
  contact_phone   text    DEFAULT '',
  contact_fax     text    DEFAULT '',
  contact_email   text    DEFAULT '',
  -- โซเชียล
  facebook_url    text    DEFAULT '',
  line_url        text    DEFAULT '',
  youtube_url     text    DEFAULT '',
  website_url     text    DEFAULT '',
  -- ฟีเจอร์ toggle
  allow_teacher_register  boolean DEFAULT true,
  show_public_stats       boolean DEFAULT true,
  show_public_news        boolean DEFAULT true,
  show_public_works       boolean DEFAULT true,
  -- school email domain (ใช้ตรวจสอบ school user)
  school_email_domain text DEFAULT '@school.ac.th',
  -- meta
  updated_at      timestamptz DEFAULT now(),
  CONSTRAINT area_config_singleton CHECK (id = 1)
);

-- Insert default row ถ้ายังไม่มี
INSERT INTO public.area_config (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

-- RLS
ALTER TABLE public.area_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "area_config public read"
  ON public.area_config FOR SELECT USING (true);
CREATE POLICY "area_config admin write"
  ON public.area_config FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );


-- ── 2. SCHOOLS ────────────────────────────────────────────────
-- ทำเนียบโรงเรียนทั้งหมดในสังกัด
CREATE TABLE IF NOT EXISTS public.schools (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_code     text UNIQUE NOT NULL,             -- รหัส smis 10 หลัก
  name            text NOT NULL,
  name_short      text DEFAULT '',
  size_type       text DEFAULT 'medium'
    CHECK (size_type IN ('large','medium','small','micro')),
  level_type      text DEFAULT 'primary'
    CHECK (level_type IN ('primary','secondary','special','expand')),
  address         text DEFAULT '',
  tambon          text DEFAULT '',
  amphoe          text DEFAULT '',
  province        text DEFAULT '',
  zipcode         text DEFAULT '',
  phone           text DEFAULT '',
  email           text DEFAULT '',
  website         text DEFAULT '',
  director_name   text DEFAULT '',
  lat             numeric(10,7),
  lng             numeric(10,7),
  is_active       boolean DEFAULT true,
  created_at      timestamptz DEFAULT now()
);

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
CREATE POLICY "schools public read"   ON public.schools FOR SELECT USING (true);
CREATE POLICY "schools admin write"   ON public.schools FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin')));


-- ── 3. UPDATE PROFILES ────────────────────────────────────────
-- เพิ่ม columns ใหม่บน profiles table ที่มีอยู่แล้ว
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS role            text NOT NULL DEFAULT 'teacher'
    CHECK (role IN ('super_admin','admin','supervisor','staff','school','teacher')),
  ADD COLUMN IF NOT EXISTS phone           text DEFAULT '',
  ADD COLUMN IF NOT EXISTS line_id         text DEFAULT '',
  -- สำหรับ supervisor
  ADD COLUMN IF NOT EXISTS subject_group   text DEFAULT '',  -- กลุ่มสาระรับผิดชอบ
  ADD COLUMN IF NOT EXISTS work_group      text DEFAULT '',  -- กลุ่มงาน (curriculum/supervision/evaluation ฯลฯ)
  -- สำหรับ school
  ADD COLUMN IF NOT EXISTS school_id       uuid REFERENCES public.schools(id),
  -- สำหรับ teacher
  ADD COLUMN IF NOT EXISTS teacher_code    text DEFAULT '',  -- รหัสครู
  ADD COLUMN IF NOT EXISTS school_name     text DEFAULT '',  -- ชื่อโรงเรียน (สำหรับครูที่สมัครเอง)
  -- approval flow
  ADD COLUMN IF NOT EXISTS is_active       boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_approved     boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS approved_at     timestamptz,
  ADD COLUMN IF NOT EXISTS approved_by     uuid REFERENCES public.profiles(id),
  ADD COLUMN IF NOT EXISTS reject_reason   text DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_login_at   timestamptz,
  ADD COLUMN IF NOT EXISTS created_at      timestamptz DEFAULT now();

-- Migrate is_admin → role (ถ้ามีคอลัมน์เดิม)
UPDATE public.profiles SET role = 'admin', is_approved = true
WHERE is_admin = true AND role = 'teacher';

UPDATE public.profiles SET is_approved = true
WHERE role IN ('super_admin','admin','supervisor','staff','school');


-- ── 4. PAGES (CMS) ────────────────────────────────────────────
-- หน้าเนื้อหาที่ admin จัดการได้
CREATE TABLE IF NOT EXISTS public.pages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text UNIQUE NOT NULL,  -- vision, org, personnel, curriculum ฯลฯ
  title       text NOT NULL,
  icon        text DEFAULT '📄',
  -- เนื้อหาหลัก (JSON array ของ content blocks)
  blocks      jsonb DEFAULT '[]'::jsonb,
  -- สถานะ
  is_published boolean DEFAULT false,
  -- meta
  created_by  uuid REFERENCES public.profiles(id),
  updated_by  uuid REFERENCES public.profiles(id),
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- Pre-populate slugs
INSERT INTO public.pages (slug, title, icon, is_published) VALUES
  ('vision',         'วิสัยทัศน์และพันธกิจ',           '👁️',  false),
  ('org',            'โครงสร้างการบริหาร',              '🏢',  false),
  ('personnel',      'ทำเนียบบุคลากร',                  '👥',  false),
  ('site-info',      'ข้อมูลสารสนเทศ',                  '📊',  false),
  ('curriculum',     'พัฒนาหลักสูตรการศึกษา',           '📖',  false),
  ('supervision-edu','นิเทศการศึกษา',                   '🔍',  false),
  ('evaluation',     'วัดและประเมินผลการศึกษา',         '📊',  false),
  ('quality',        'ประกันคุณภาพการศึกษา',             '⭐',  false),
  ('research',       'วิจัย สื่อ และเทคโนโลยี',        '🔬',  false),
  ('secretariat',    'ส่งเสริมพัฒนาระบบการบริหารจัดการ','📋',  false)
ON CONFLICT (slug) DO NOTHING;

ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pages public read published"
  ON public.pages FOR SELECT USING (is_published = true OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );
CREATE POLICY "pages admin write"
  ON public.pages FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 5. NEWS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.news (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category    text NOT NULL DEFAULT 'pr'
    CHECK (category IN ('pr','supervision','training','policy','other')),
  title       text NOT NULL,
  excerpt     text DEFAULT '',
  content     text DEFAULT '',
  cover_url   text DEFAULT '',
  file_url    text DEFAULT '',
  is_pinned   boolean DEFAULT false,
  is_published boolean DEFAULT false,
  published_at timestamptz,
  created_by  uuid REFERENCES public.profiles(id),
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;
CREATE POLICY "news public read"   ON public.news FOR SELECT USING (is_published = true OR
  EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));
CREATE POLICY "news staff write"   ON public.news FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 6. DOCUMENTS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.documents (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category    text NOT NULL DEFAULT 'form'
    CHECK (category IN ('form','supervision','curriculum','report','policy','other')),
  title       text NOT NULL,
  description text DEFAULT '',
  file_url    text NOT NULL,
  file_type   text DEFAULT 'PDF',   -- PDF, DOCX, XLSX, PPTX
  file_size   text DEFAULT '',
  download_count int DEFAULT 0,
  is_published boolean DEFAULT true,
  sort_order  int DEFAULT 0,
  created_by  uuid REFERENCES public.profiles(id),
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "documents public read"  ON public.documents FOR SELECT USING (is_published = true);
CREATE POLICY "documents staff write"  ON public.documents FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 7. WORKS (ผลงาน) ──────────────────────────────────────────
-- ผลงานของ ศน. และครูที่ส่งเข้ามา
CREATE TABLE IF NOT EXISTS public.works (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_type   text NOT NULL DEFAULT 'research'
    CHECK (work_type IN ('research','innovation','best_practice','lesson_plan','other')),
  owner_type  text NOT NULL DEFAULT 'supervisor'
    CHECK (owner_type IN ('supervisor','teacher','school')),
  title       text NOT NULL,
  description text DEFAULT '',
  subject     text DEFAULT '',      -- กลุ่มสาระ
  grade_level text DEFAULT '',      -- ระดับชั้น
  file_url    text DEFAULT '',
  cover_url   text DEFAULT '',
  tags        text[] DEFAULT '{}',
  -- approval
  status      text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  reject_reason text DEFAULT '',
  approved_by uuid REFERENCES public.profiles(id),
  approved_at timestamptz,
  -- owner
  owner_id    uuid NOT NULL REFERENCES public.profiles(id),
  school_name text DEFAULT '',
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.works ENABLE ROW LEVEL SECURITY;
CREATE POLICY "works public read approved" ON public.works FOR SELECT
  USING (status = 'approved' OR owner_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor')));
CREATE POLICY "works owner insert" ON public.works FOR INSERT
  WITH CHECK (owner_id = auth.uid() AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_approved = true));
CREATE POLICY "works admin manage" ON public.works FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor')));


-- ── 8. SHORT URLS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.short_urls (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text UNIQUE NOT NULL,
  target_url  text NOT NULL,
  click_count int DEFAULT 0,
  created_by  uuid REFERENCES public.profiles(id),
  expires_at  timestamptz,
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.short_urls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "short_urls auth read"   ON public.short_urls FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));
CREATE POLICY "short_urls auth write"  ON public.short_urls FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 9. HANDLE NEW USER (trigger) ─────────────────────────────
-- สร้าง profile อัตโนมัติตอน sign up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  _role text := 'teacher';
  _approved boolean := false;
BEGIN
  -- ถ้า email match admin domain → ยังคง teacher รอ approve
  -- Super admin ต้อง set manually ใน DB
  INSERT INTO public.profiles (id, email, full_name, role, is_approved, is_active)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    _role,
    _approved,
    true
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ── 10. RPC: get_area_config (public) ────────────────────────
CREATE OR REPLACE FUNCTION public.get_area_config()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT row_to_json(a)::jsonb FROM public.area_config a WHERE id = 1;
$$;
GRANT EXECUTE ON FUNCTION public.get_area_config() TO anon, authenticated;


-- ── 11. RPC: get_my_profile ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT row_to_json(p)::jsonb
  FROM public.profiles p
  WHERE p.id = auth.uid();
$$;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;


-- ── INDEXES ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_role      ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_school    ON public.profiles(school_id);
CREATE INDEX IF NOT EXISTS idx_profiles_approved  ON public.profiles(is_approved);
CREATE INDEX IF NOT EXISTS idx_news_category      ON public.news(category, is_published);
CREATE INDEX IF NOT EXISTS idx_works_status       ON public.works(status, owner_type);
CREATE INDEX IF NOT EXISTS idx_documents_category ON public.documents(category, is_published);
CREATE INDEX IF NOT EXISTS idx_short_urls_slug    ON public.short_urls(slug);
