-- ============================================================
-- PATCH V2 COMPLETE — รันอย่างปลอดภัย ไม่ต้อง DROP อะไรก่อน
-- จัดการ: profiles columns + สร้างตารางที่ขาด + policies + indexes
-- ============================================================

-- ── 1. FIX PROFILES COLUMNS (ทีละ column ผ่าน DO block) ──────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='role') THEN
    ALTER TABLE public.profiles ADD COLUMN role text DEFAULT 'teacher';
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
      CHECK (role IN ('super_admin','admin','supervisor','staff','school','teacher'));
    UPDATE public.profiles SET role = 'teacher' WHERE role IS NULL;
    ALTER TABLE public.profiles ALTER COLUMN role SET NOT NULL;
    RAISE NOTICE '✅ Added: role';
  ELSE RAISE NOTICE '⏭ Skip: role (exists)'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='phone') THEN
    ALTER TABLE public.profiles ADD COLUMN phone text DEFAULT '';
    RAISE NOTICE '✅ Added: phone';
  ELSE RAISE NOTICE '⏭ Skip: phone'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='line_id') THEN
    ALTER TABLE public.profiles ADD COLUMN line_id text DEFAULT '';
    RAISE NOTICE '✅ Added: line_id';
  ELSE RAISE NOTICE '⏭ Skip: line_id'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='subject_group') THEN
    ALTER TABLE public.profiles ADD COLUMN subject_group text DEFAULT '';
    RAISE NOTICE '✅ Added: subject_group';
  ELSE RAISE NOTICE '⏭ Skip: subject_group'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='work_group') THEN
    ALTER TABLE public.profiles ADD COLUMN work_group text DEFAULT '';
    RAISE NOTICE '✅ Added: work_group';
  ELSE RAISE NOTICE '⏭ Skip: work_group'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='school_id') THEN
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema='public' AND table_name='schools') THEN
      ALTER TABLE public.profiles ADD COLUMN school_id uuid REFERENCES public.schools(id);
    ELSE
      ALTER TABLE public.profiles ADD COLUMN school_id uuid;
    END IF;
    RAISE NOTICE '✅ Added: school_id';
  ELSE RAISE NOTICE '⏭ Skip: school_id'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='teacher_code') THEN
    ALTER TABLE public.profiles ADD COLUMN teacher_code text DEFAULT '';
    RAISE NOTICE '✅ Added: teacher_code';
  ELSE RAISE NOTICE '⏭ Skip: teacher_code'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='school_name') THEN
    ALTER TABLE public.profiles ADD COLUMN school_name text DEFAULT '';
    RAISE NOTICE '✅ Added: school_name';
  ELSE RAISE NOTICE '⏭ Skip: school_name'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='is_active') THEN
    ALTER TABLE public.profiles ADD COLUMN is_active boolean DEFAULT true;
    RAISE NOTICE '✅ Added: is_active';
  ELSE RAISE NOTICE '⏭ Skip: is_active'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='is_approved') THEN
    ALTER TABLE public.profiles ADD COLUMN is_approved boolean DEFAULT false;
    RAISE NOTICE '✅ Added: is_approved';
  ELSE RAISE NOTICE '⏭ Skip: is_approved'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='approved_at') THEN
    ALTER TABLE public.profiles ADD COLUMN approved_at timestamptz;
    RAISE NOTICE '✅ Added: approved_at';
  ELSE RAISE NOTICE '⏭ Skip: approved_at'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='approved_by') THEN
    ALTER TABLE public.profiles ADD COLUMN approved_by uuid REFERENCES public.profiles(id);
    RAISE NOTICE '✅ Added: approved_by';
  ELSE RAISE NOTICE '⏭ Skip: approved_by'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='reject_reason') THEN
    ALTER TABLE public.profiles ADD COLUMN reject_reason text DEFAULT '';
    RAISE NOTICE '✅ Added: reject_reason';
  ELSE RAISE NOTICE '⏭ Skip: reject_reason'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='last_login_at') THEN
    ALTER TABLE public.profiles ADD COLUMN last_login_at timestamptz;
    RAISE NOTICE '✅ Added: last_login_at';
  ELSE RAISE NOTICE '⏭ Skip: last_login_at'; END IF;

  RAISE NOTICE '✅ profiles columns done';
END $$;


-- ── 2. MIGRATE is_admin → role ────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='is_admin') THEN
    UPDATE public.profiles SET role='admin', is_approved=true WHERE is_admin=true AND role='teacher';
    RAISE NOTICE '✅ Migrated is_admin → role';
  END IF;
END $$;

UPDATE public.profiles SET is_approved=true
WHERE role IN ('super_admin','admin','supervisor','staff','school')
  AND (is_approved IS NULL OR is_approved=false);


-- ── 3. PROFILES RLS policies (DROP first → recreate) ─────────
DO $$
BEGIN
  -- drop ถ้ามีอยู่แล้ว (ป้องกัน "already exists")
  DROP POLICY IF EXISTS "profiles public read"  ON public.profiles;
  DROP POLICY IF EXISTS "profiles self update"  ON public.profiles;
  DROP POLICY IF EXISTS "profiles admin manage" ON public.profiles;
  RAISE NOTICE '✅ profiles policies cleared';
END $$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "profiles public read"
  ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles self update"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);
CREATE POLICY "profiles admin manage"
  ON public.profiles FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.profiles p2
    WHERE p2.id = auth.uid() AND p2.role IN ('super_admin','admin')
  ));


-- ── 4. SCHOOLS (สร้างถ้ายังไม่มี) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.schools (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_code   text UNIQUE NOT NULL,
  name          text NOT NULL,
  name_short    text DEFAULT '',
  size_type     text DEFAULT 'medium'
    CHECK (size_type IN ('large','medium','small','micro')),
  level_type    text DEFAULT 'primary'
    CHECK (level_type IN ('primary','secondary','special','expand')),
  address       text DEFAULT '',
  tambon        text DEFAULT '',
  amphoe        text DEFAULT '',
  province      text DEFAULT '',
  zipcode       text DEFAULT '',
  phone         text DEFAULT '',
  email         text DEFAULT '',
  website       text DEFAULT '',
  director_name text DEFAULT '',
  lat           numeric(10,7),
  lng           numeric(10,7),
  is_active     boolean DEFAULT true,
  created_at    timestamptz DEFAULT now()
);

DO $$
BEGIN
  DROP POLICY IF EXISTS "schools public read"  ON public.schools;
  DROP POLICY IF EXISTS "schools admin write"  ON public.schools;
END $$;
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
CREATE POLICY "schools public read" ON public.schools FOR SELECT USING (true);
CREATE POLICY "schools admin write" ON public.schools FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin')));


-- ── 5. AREA CONFIG (สร้างถ้ายังไม่มี) ────────────────────────
CREATE TABLE IF NOT EXISTS public.area_config (
  id                      smallint PRIMARY KEY DEFAULT 1,
  area_name               text NOT NULL DEFAULT 'กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
  area_name_short         text NOT NULL DEFAULT 'กลุ่มนิเทศฯ',
  area_type               text NOT NULL DEFAULT 'สพป.',
  province                text NOT NULL DEFAULT '',
  area_number             text DEFAULT '',
  logo_url                text DEFAULT '',
  primary_color           text DEFAULT '#2563eb',
  secondary_color         text DEFAULT '#4f46e5',
  contact_address         text DEFAULT '',
  contact_phone           text DEFAULT '',
  contact_fax             text DEFAULT '',
  contact_email           text DEFAULT '',
  facebook_url            text DEFAULT '',
  line_url                text DEFAULT '',
  youtube_url             text DEFAULT '',
  website_url             text DEFAULT '',
  allow_teacher_register  boolean DEFAULT true,
  show_public_stats       boolean DEFAULT true,
  show_public_news        boolean DEFAULT true,
  show_public_works       boolean DEFAULT true,
  school_email_domain     text DEFAULT '@school.ac.th',
  updated_at              timestamptz DEFAULT now(),
  CONSTRAINT area_config_singleton CHECK (id = 1)
);

INSERT INTO public.area_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  DROP POLICY IF EXISTS "area_config public read"  ON public.area_config;
  DROP POLICY IF EXISTS "area_config admin write"  ON public.area_config;
END $$;
ALTER TABLE public.area_config ENABLE ROW LEVEL SECURITY;
CREATE POLICY "area_config public read" ON public.area_config FOR SELECT USING (true);
CREATE POLICY "area_config admin write" ON public.area_config FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin')));


-- ── 6. PAGES (CMS) ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.pages (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text UNIQUE NOT NULL,
  title       text NOT NULL,
  icon        text DEFAULT '📄',
  blocks      jsonb DEFAULT '[]'::jsonb,
  is_published boolean DEFAULT false,
  created_by  uuid REFERENCES public.profiles(id),
  updated_by  uuid REFERENCES public.profiles(id),
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

INSERT INTO public.pages (slug, title, icon, is_published) VALUES
  ('vision',         'วิสัยทัศน์และพันธกิจ',            '👁️', false),
  ('org',            'โครงสร้างการบริหาร',               '🏢', false),
  ('personnel',      'ทำเนียบบุคลากร',                   '👥', false),
  ('site-info',      'ข้อมูลสารสนเทศ',                   '📊', false),
  ('curriculum',     'พัฒนาหลักสูตรการศึกษา',            '📖', false),
  ('supervision-edu','นิเทศการศึกษา',                    '🔍', false),
  ('evaluation',     'วัดและประเมินผลการศึกษา',          '📊', false),
  ('quality',        'ประกันคุณภาพการศึกษา',              '⭐', false),
  ('research',       'วิจัย สื่อ และเทคโนโลยี',         '🔬', false),
  ('secretariat',    'ส่งเสริมพัฒนาระบบการบริหารจัดการ', '📋', false)
ON CONFLICT (slug) DO NOTHING;

DO $$
BEGIN
  DROP POLICY IF EXISTS "pages public read published" ON public.pages;
  DROP POLICY IF EXISTS "pages admin write"           ON public.pages;
END $$;
ALTER TABLE public.pages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "pages public read published" ON public.pages FOR SELECT
  USING (is_published=true OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')
  ));
CREATE POLICY "pages admin write" ON public.pages FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 7. NEWS ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.news (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category     text NOT NULL DEFAULT 'pr'
    CHECK (category IN ('pr','supervision','training','policy','other')),
  title        text NOT NULL,
  excerpt      text DEFAULT '',
  content      text DEFAULT '',
  cover_url    text DEFAULT '',
  file_url     text DEFAULT '',
  is_pinned    boolean DEFAULT false,
  is_published boolean DEFAULT false,
  published_at timestamptz,
  created_by   uuid REFERENCES public.profiles(id),
  created_at   timestamptz DEFAULT now()
);

DO $$
BEGIN
  DROP POLICY IF EXISTS "news public read"  ON public.news;
  DROP POLICY IF EXISTS "news staff write"  ON public.news;
END $$;
ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;
CREATE POLICY "news public read" ON public.news FOR SELECT
  USING (is_published=true OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')
  ));
CREATE POLICY "news staff write" ON public.news FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 8. DOCUMENTS ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.documents (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category       text NOT NULL DEFAULT 'form'
    CHECK (category IN ('form','supervision','curriculum','report','policy','other')),
  title          text NOT NULL,
  description    text DEFAULT '',
  file_url       text NOT NULL,
  file_type      text DEFAULT 'PDF',
  file_size      text DEFAULT '',
  download_count int  DEFAULT 0,
  is_published   boolean DEFAULT true,
  sort_order     int  DEFAULT 0,
  created_by     uuid REFERENCES public.profiles(id),
  created_at     timestamptz DEFAULT now()
);

DO $$
BEGIN
  DROP POLICY IF EXISTS "documents public read"  ON public.documents;
  DROP POLICY IF EXISTS "documents staff write"  ON public.documents;
END $$;
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "documents public read" ON public.documents FOR SELECT USING (is_published=true);
CREATE POLICY "documents staff write" ON public.documents FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 9. WORKS ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.works (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_type     text NOT NULL DEFAULT 'research'
    CHECK (work_type IN ('research','innovation','best_practice','lesson_plan','other')),
  owner_type    text NOT NULL DEFAULT 'supervisor'
    CHECK (owner_type IN ('supervisor','teacher','school')),
  title         text NOT NULL,
  description   text DEFAULT '',
  subject       text DEFAULT '',
  grade_level   text DEFAULT '',
  file_url      text DEFAULT '',
  cover_url     text DEFAULT '',
  tags          text[] DEFAULT '{}',
  status        text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  reject_reason text DEFAULT '',
  approved_by   uuid REFERENCES public.profiles(id),
  approved_at   timestamptz,
  owner_id      uuid NOT NULL REFERENCES public.profiles(id),
  school_name   text DEFAULT '',
  created_at    timestamptz DEFAULT now()
);

DO $$
BEGIN
  DROP POLICY IF EXISTS "works public read approved" ON public.works;
  DROP POLICY IF EXISTS "works owner insert"         ON public.works;
  DROP POLICY IF EXISTS "works admin manage"         ON public.works;
END $$;
ALTER TABLE public.works ENABLE ROW LEVEL SECURITY;
CREATE POLICY "works public read approved" ON public.works FOR SELECT
  USING (status='approved' OR owner_id=auth.uid() OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor')
  ));
CREATE POLICY "works owner insert" ON public.works FOR INSERT
  WITH CHECK (owner_id=auth.uid() AND EXISTS (
    SELECT 1 FROM public.profiles WHERE id=auth.uid() AND is_approved=true
  ));
CREATE POLICY "works admin manage" ON public.works FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor')));


-- ── 10. SHORT URLS ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.short_urls (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug        text UNIQUE NOT NULL,
  target_url  text NOT NULL,
  click_count int  DEFAULT 0,
  created_by  uuid REFERENCES public.profiles(id),
  expires_at  timestamptz,
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

DO $$
BEGIN
  DROP POLICY IF EXISTS "short_urls auth read"  ON public.short_urls;
  DROP POLICY IF EXISTS "short_urls auth write" ON public.short_urls;
END $$;
ALTER TABLE public.short_urls ENABLE ROW LEVEL SECURITY;
CREATE POLICY "short_urls auth read" ON public.short_urls FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));
CREATE POLICY "short_urls auth write" ON public.short_urls FOR ALL
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));


-- ── 11. TRIGGER: handle_new_user ─────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, role, is_approved, is_active)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email,'@',1)),
    'teacher',
    false,
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


-- ── 12. RPC FUNCTIONS ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_area_config()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT row_to_json(a)::jsonb FROM public.area_config a WHERE id=1;
$$;
GRANT EXECUTE ON FUNCTION public.get_area_config() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT row_to_json(p)::jsonb FROM public.profiles p WHERE p.id=auth.uid();
$$;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;


-- ── 13. INDEXES ───────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_role      ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_school    ON public.profiles(school_id);
CREATE INDEX IF NOT EXISTS idx_profiles_approved  ON public.profiles(is_approved);
CREATE INDEX IF NOT EXISTS idx_news_category      ON public.news(category, is_published);
CREATE INDEX IF NOT EXISTS idx_works_status       ON public.works(status, owner_type);
CREATE INDEX IF NOT EXISTS idx_documents_category ON public.documents(category, is_published);
CREATE INDEX IF NOT EXISTS idx_short_urls_slug    ON public.short_urls(slug);


-- ── ✅ ตรวจสอบผลลัพธ์ ──────────────────────────────────────────
SELECT
  table_name,
  (SELECT count(*) FROM information_schema.columns c
   WHERE c.table_schema='public' AND c.table_name=t.table_name) AS col_count
FROM information_schema.tables t
WHERE table_schema='public'
  AND table_name IN ('profiles','schools','area_config','pages','news','documents','works','short_urls')
ORDER BY table_name;
