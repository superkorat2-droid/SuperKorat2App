-- ============================================================
-- patch_schools_system.sql
-- สร้างตาราง schools + dmc_uploads + RLS + RPC
-- รันปลอดภัย ซ้ำได้
-- ============================================================

-- ── 0. Drop and recreate schools (safe — ยังไม่มีข้อมูล) ────────
DROP TABLE IF EXISTS public.dmc_uploads CASCADE;
DROP TABLE IF EXISTS public.schools CASCADE;

-- ── 1. ตาราง schools (master data โรงเรียน) ──────────────────
CREATE TABLE public.schools (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dmc_code      text UNIQUE NOT NULL,   -- 30020001
  per_code      text NOT NULL DEFAULT '',
  school_code   text NOT NULL DEFAULT '',  -- รหัส 10 หลัก
  name          text NOT NULL DEFAULT '',
  village_no    text NOT NULL DEFAULT '',
  village_name  text NOT NULL DEFAULT '',
  subdistrict   text NOT NULL DEFAULT '',
  district      text NOT NULL DEFAULT '',
  school_group  text NOT NULL DEFAULT '',
  postal_code   text NOT NULL DEFAULT '',
  email         text UNIQUE NOT NULL,   -- 30020001@korat2.go.th
  website_url   text NOT NULL DEFAULT '',
  distance_km   numeric,
  lat           numeric,
  lng           numeric,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- ── 2. FK profiles.school_id → schools.id (เพิ่มถ้ายังไม่มี) ──
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'profiles_school_id_fkey'
      AND table_schema = 'public'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_school_id_fkey
      FOREIGN KEY (school_id) REFERENCES public.schools(id);
    RAISE NOTICE '✅ Added FK profiles.school_id → schools.id';
  ELSE
    RAISE NOTICE '⏭ Skip FK (exists)';
  END IF;
END $$;

-- ── 3. ตาราง dmc_uploads (ประวัติ upload ไฟล์ DMC) ──────────
CREATE TABLE public.dmc_uploads (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id     uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  uploaded_by   uuid REFERENCES auth.users(id),
  file_name     text NOT NULL,
  file_url      text NOT NULL,           -- Supabase Storage URL
  file_type     text NOT NULL DEFAULT '', -- 'excel' | 'csv'
  file_size     bigint,
  academic_year text NOT NULL DEFAULT '', -- ปีการศึกษา เช่น '2567'
  term          text NOT NULL DEFAULT '', -- '1' | '2'
  status        text NOT NULL DEFAULT 'pending',
  -- 'pending' | 'processing' | 'done' | 'error'
  note          text NOT NULL DEFAULT '',
  row_count     int,                     -- จำนวน record ในไฟล์
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- ── 4. Indexes ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_schools_district      ON public.schools(district);
CREATE INDEX IF NOT EXISTS idx_schools_school_group  ON public.schools(school_group);
CREATE INDEX IF NOT EXISTS idx_schools_dmc_code      ON public.schools(dmc_code);
CREATE INDEX IF NOT EXISTS idx_dmc_uploads_school    ON public.dmc_uploads(school_id);
CREATE INDEX IF NOT EXISTS idx_dmc_uploads_created   ON public.dmc_uploads(created_at DESC);

-- ── 5. updated_at trigger ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS schools_updated_at ON public.schools;
CREATE TRIGGER schools_updated_at
  BEFORE UPDATE ON public.schools
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 6. RLS ────────────────────────────────────────────────────
ALTER TABLE public.schools     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dmc_uploads ENABLE ROW LEVEL SECURITY;

-- schools: public อ่านได้ทุกคน
DROP POLICY IF EXISTS "schools_public_read"   ON public.schools;
CREATE POLICY "schools_public_read" ON public.schools
  FOR SELECT USING (true);

-- schools: admin/super_admin แก้ไขได้
DROP POLICY IF EXISTS "schools_admin_all"     ON public.schools;
CREATE POLICY "schools_admin_all" ON public.schools
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND role IN ('super_admin','admin')
        AND is_approved = true
    )
  );

-- schools: โรงเรียนแก้ไขข้อมูลตัวเองได้ (website_url, ฯลฯ)
DROP POLICY IF EXISTS "schools_self_update"   ON public.schools;
CREATE POLICY "schools_self_update" ON public.schools
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND school_id = schools.id
        AND role = 'school'
        AND is_approved = true
    )
  );

-- dmc_uploads: โรงเรียนเห็นและสร้างของตัวเอง
DROP POLICY IF EXISTS "dmc_own_read"          ON public.dmc_uploads;
CREATE POLICY "dmc_own_read" ON public.dmc_uploads
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

DROP POLICY IF EXISTS "dmc_school_insert"     ON public.dmc_uploads;
CREATE POLICY "dmc_school_insert" ON public.dmc_uploads
  FOR INSERT WITH CHECK (
    school_id IN (
      SELECT school_id FROM public.profiles
      WHERE id = auth.uid()
        AND role = 'school'
        AND is_approved = true
    )
  );

-- dmc_uploads: admin จัดการได้ทุกอย่าง
DROP POLICY IF EXISTS "dmc_admin_all"         ON public.dmc_uploads;
CREATE POLICY "dmc_admin_all" ON public.dmc_uploads
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid()
        AND role IN ('super_admin','admin')
        AND is_approved = true
    )
  );

-- ── 7. RPC: get_my_school ─────────────────────────────────────
-- โรงเรียน query ข้อมูลตัวเอง (ใช้ใน school portal)
CREATE OR REPLACE FUNCTION public.get_my_school()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT row_to_json(s)::jsonb
  FROM public.schools s
  INNER JOIN public.profiles p ON p.school_id = s.id
  WHERE p.id = auth.uid()
    AND p.is_approved = true
  LIMIT 1;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_school() TO authenticated;

-- ── 8. RPC: get_schools_public ────────────────────────────────
-- ทำเนียบโรงเรียนสาธารณะ (anon เรียกได้)
CREATE OR REPLACE FUNCTION public.get_schools_public()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT json_agg(
    json_build_object(
      'id',           s.id,
      'dmc_code',     s.dmc_code,
      'name',         s.name,
      'subdistrict',  s.subdistrict,
      'district',     s.district,
      'school_group', s.school_group,
      'email',        s.email,
      'website_url',  s.website_url,
      'lat',          s.lat,
      'lng',          s.lng,
      'distance_km',  s.distance_km,
      'is_active',    s.is_active
    ) ORDER BY s.district, s.school_group, s.name
  )::jsonb
  FROM public.schools s
  WHERE s.is_active = true;
$$;
GRANT EXECUTE ON FUNCTION public.get_schools_public() TO anon, authenticated;

-- ── 9. Storage bucket: dmc-files ─────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'dmc-files',
  'dmc-files',
  false,
  10485760,  -- 10 MB
  ARRAY[
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel',
    'text/csv',
    'application/csv'
  ]
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies: โรงเรียน upload ในโฟลเดอร์ตัวเอง
DROP POLICY IF EXISTS "dmc_files_school_upload" ON storage.objects;
CREATE POLICY "dmc_files_school_upload" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'dmc-files'
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      INNER JOIN public.schools s ON s.id = p.school_id
      WHERE p.id = auth.uid()
        AND p.role = 'school'
        AND p.is_approved = true
        AND (storage.foldername(name))[1] = s.dmc_code
    )
  );

DROP POLICY IF EXISTS "dmc_files_school_read" ON storage.objects;
CREATE POLICY "dmc_files_school_read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'dmc-files'
    AND (
      EXISTS (
        SELECT 1 FROM public.profiles p
        INNER JOIN public.schools s ON s.id = p.school_id
        WHERE p.id = auth.uid()
          AND p.is_approved = true
          AND (storage.foldername(name))[1] = s.dmc_code
      )
      OR EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid()
          AND role IN ('super_admin','admin','supervisor')
      )
    )
  );

-- ── ✅ Done ───────────────────────────────────────────────────
DO $$ BEGIN
  RAISE NOTICE '✅ patch_schools_system.sql complete';
END $$;
