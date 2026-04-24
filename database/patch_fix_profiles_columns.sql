-- ============================================================
-- PATCH: Fix profiles columns (แก้ปัญหา column "role" does not exist)
-- รันใน Supabase SQL Editor แยกจาก migration_v2_roles_schema.sql
-- ============================================================
-- สาเหตุ: ALTER TABLE ก้อนใหญ่ใน V2 ล้มเหลวเพราะบางคอลัมน์มีอยู่แล้ว
-- (เช่น created_at) ทำให้ทั้งก้อน rollback — role ไม่ถูกสร้าง
-- Patch นี้ใช้ DO $$ เพื่อเช็คทีละคอลัมน์ก่อน ADD
-- ============================================================

DO $$
DECLARE
  col_exists boolean;
BEGIN

  -- ── role ──────────────────────────────────────────────────────
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'role'
  ) INTO col_exists;

  IF NOT col_exists THEN
    ALTER TABLE public.profiles ADD COLUMN role text DEFAULT 'teacher';
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
      CHECK (role IN ('super_admin','admin','supervisor','staff','school','teacher'));
    -- ตั้งค่า NOT NULL หลังจาก default ถูก populate แล้ว
    UPDATE public.profiles SET role = 'teacher' WHERE role IS NULL;
    ALTER TABLE public.profiles ALTER COLUMN role SET NOT NULL;
    RAISE NOTICE 'Added column: role';
  ELSE
    RAISE NOTICE 'Column role already exists — skipped';
  END IF;

  -- ── phone ─────────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='phone') THEN
    ALTER TABLE public.profiles ADD COLUMN phone text DEFAULT '';
    RAISE NOTICE 'Added column: phone';
  END IF;

  -- ── line_id ───────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='line_id') THEN
    ALTER TABLE public.profiles ADD COLUMN line_id text DEFAULT '';
    RAISE NOTICE 'Added column: line_id';
  END IF;

  -- ── subject_group ─────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='subject_group') THEN
    ALTER TABLE public.profiles ADD COLUMN subject_group text DEFAULT '';
    RAISE NOTICE 'Added column: subject_group';
  END IF;

  -- ── work_group ────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='work_group') THEN
    ALTER TABLE public.profiles ADD COLUMN work_group text DEFAULT '';
    RAISE NOTICE 'Added column: work_group';
  END IF;

  -- ── school_id ─────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='school_id') THEN
    -- ตรวจว่า schools table มีอยู่แล้วหรือไม่ก่อน ADD FK
    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema='public' AND table_name='schools') THEN
      ALTER TABLE public.profiles ADD COLUMN school_id uuid REFERENCES public.schools(id);
    ELSE
      ALTER TABLE public.profiles ADD COLUMN school_id uuid;
    END IF;
    RAISE NOTICE 'Added column: school_id';
  END IF;

  -- ── teacher_code ──────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='teacher_code') THEN
    ALTER TABLE public.profiles ADD COLUMN teacher_code text DEFAULT '';
    RAISE NOTICE 'Added column: teacher_code';
  END IF;

  -- ── school_name ───────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='school_name') THEN
    ALTER TABLE public.profiles ADD COLUMN school_name text DEFAULT '';
    RAISE NOTICE 'Added column: school_name';
  END IF;

  -- ── is_active ─────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='is_active') THEN
    ALTER TABLE public.profiles ADD COLUMN is_active boolean DEFAULT true;
    RAISE NOTICE 'Added column: is_active';
  END IF;

  -- ── is_approved ───────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='is_approved') THEN
    ALTER TABLE public.profiles ADD COLUMN is_approved boolean DEFAULT false;
    RAISE NOTICE 'Added column: is_approved';
  END IF;

  -- ── approved_at ───────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='approved_at') THEN
    ALTER TABLE public.profiles ADD COLUMN approved_at timestamptz;
    RAISE NOTICE 'Added column: approved_at';
  END IF;

  -- ── approved_by (self-ref FK) ─────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='approved_by') THEN
    ALTER TABLE public.profiles ADD COLUMN approved_by uuid REFERENCES public.profiles(id);
    RAISE NOTICE 'Added column: approved_by';
  END IF;

  -- ── reject_reason ─────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='reject_reason') THEN
    ALTER TABLE public.profiles ADD COLUMN reject_reason text DEFAULT '';
    RAISE NOTICE 'Added column: reject_reason';
  END IF;

  -- ── last_login_at ─────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='last_login_at') THEN
    ALTER TABLE public.profiles ADD COLUMN last_login_at timestamptz;
    RAISE NOTICE 'Added column: last_login_at';
  END IF;

  -- ── created_at (อาจมีอยู่แล้วจาก Supabase default) ───────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='created_at') THEN
    ALTER TABLE public.profiles ADD COLUMN created_at timestamptz DEFAULT now();
    RAISE NOTICE 'Added column: created_at';
  ELSE
    RAISE NOTICE 'Column created_at already exists — skipped (ปกติ)';
  END IF;

END $$;


-- ── Migrate is_admin → role ────────────────────────────────────
-- ถ้ามี column is_admin เดิม → copy ค่าไป role
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='is_admin') THEN
    UPDATE public.profiles
    SET role = 'admin', is_approved = true
    WHERE is_admin = true AND role = 'teacher';
    RAISE NOTICE 'Migrated is_admin → role=admin';
  END IF;
END $$;

-- ทุก role ที่ไม่ใช่ teacher → auto-approve
UPDATE public.profiles
SET is_approved = true
WHERE role IN ('super_admin','admin','supervisor','staff','school')
  AND (is_approved IS NULL OR is_approved = false);


-- ── Indexes ────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_profiles_role      ON public.profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_school    ON public.profiles(school_id);
CREATE INDEX IF NOT EXISTS idx_profiles_approved  ON public.profiles(is_approved);
CREATE INDEX IF NOT EXISTS idx_news_category      ON public.news(category, is_published);
CREATE INDEX IF NOT EXISTS idx_works_status       ON public.works(status, owner_type);
CREATE INDEX IF NOT EXISTS idx_documents_category ON public.documents(category, is_published);
CREATE INDEX IF NOT EXISTS idx_short_urls_slug    ON public.short_urls(slug);


-- ── ตรวจสอบผลลัพธ์ ────────────────────────────────────────────
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'profiles'
ORDER BY ordinal_position;
