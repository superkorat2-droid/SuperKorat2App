-- ============================================================
-- PATCH: สร้าง Storage Buckets + Policies
-- รันใน Supabase SQL Editor
-- ============================================================

-- ── สร้าง buckets ──────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('logos',     'logos',     true, 5242880,  ARRAY['image/jpeg','image/png','image/webp','image/gif','image/svg+xml']),
  ('banners',   'banners',   true, 10485760, ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm']),
  ('images',    'images',    true, 10485760, ARRAY['image/jpeg','image/png','image/webp','image/gif','image/svg+xml']),
  ('documents', 'documents', true, 52428800, ARRAY['application/pdf','application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/zip','application/x-rar-compressed'])
ON CONFLICT (id) DO NOTHING;

-- ── Storage Policies ───────────────────────────────────────────
-- logos bucket
DROP POLICY IF EXISTS "logos public read"  ON storage.objects;
DROP POLICY IF EXISTS "logos auth upload"  ON storage.objects;
DROP POLICY IF EXISTS "logos auth delete"  ON storage.objects;

CREATE POLICY "logos public read" ON storage.objects FOR SELECT
  USING (bucket_id = 'logos');

CREATE POLICY "logos auth upload" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'logos' AND
    auth.role() = 'authenticated' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

CREATE POLICY "logos auth delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'logos' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

-- banners bucket
DROP POLICY IF EXISTS "banners public read" ON storage.objects;
DROP POLICY IF EXISTS "banners auth upload" ON storage.objects;
DROP POLICY IF EXISTS "banners auth delete" ON storage.objects;

CREATE POLICY "banners public read" ON storage.objects FOR SELECT
  USING (bucket_id = 'banners');

CREATE POLICY "banners auth upload" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'banners' AND
    auth.role() = 'authenticated' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

CREATE POLICY "banners auth delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'banners' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

-- images bucket (staff ขึ้นไปอัปโหลดได้)
DROP POLICY IF EXISTS "images public read" ON storage.objects;
DROP POLICY IF EXISTS "images auth upload" ON storage.objects;
DROP POLICY IF EXISTS "images auth delete" ON storage.objects;

CREATE POLICY "images public read" ON storage.objects FOR SELECT
  USING (bucket_id = 'images');

CREATE POLICY "images auth upload" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'images' AND
    auth.role() = 'authenticated' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );

CREATE POLICY "images auth delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'images' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );

-- documents bucket (staff ขึ้นไปอัปโหลดได้)
DROP POLICY IF EXISTS "documents public read" ON storage.objects;
DROP POLICY IF EXISTS "documents auth upload" ON storage.objects;
DROP POLICY IF EXISTS "documents auth delete" ON storage.objects;

CREATE POLICY "documents public read" ON storage.objects FOR SELECT
  USING (bucket_id = 'documents');

CREATE POLICY "documents auth upload" ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'documents' AND
    auth.role() = 'authenticated' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );

CREATE POLICY "documents auth delete" ON storage.objects FOR DELETE
  USING (
    bucket_id = 'documents' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );

-- ✅ ตรวจสอบ
SELECT id, name, public, file_size_limit FROM storage.buckets ORDER BY name;
