-- Migration 27: School principals directory

CREATE TABLE public.school_principals (
  id         uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id  uuid    NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  name       text    NOT NULL,
  position   text    NOT NULL,
  phone      text,
  email      text,
  line_id    text,
  photo_url  text,
  sort_order int     NOT NULL DEFAULT 0,
  visibility jsonb   NOT NULL DEFAULT '{"phone":false,"email":false,"line":false}',
  created_by uuid    REFERENCES public.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON public.school_principals (school_id);

ALTER TABLE public.school_principals ENABLE ROW LEVEL SECURITY;

-- ทุกคนอ่านได้
CREATE POLICY "principals: read all"
  ON public.school_principals FOR SELECT TO anon, authenticated
  USING (true);

-- admin จัดการได้ทุกโรง | school user จัดการของตัวเอง
CREATE POLICY "principals: write"
  ON public.school_principals FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
            AND role IN ('super_admin','admin'))
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.school_id = school_principals.school_id
    )
  );

-- Storage bucket รูปโปรไฟล์
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('principal-photos', 'principal-photos', true, 5242880,
  ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "principal photos upload"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'principal-photos');

CREATE POLICY "principal photos read"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'principal-photos');

CREATE POLICY "principal photos delete"
  ON storage.objects FOR DELETE TO authenticated
  USING (bucket_id = 'principal-photos');
