-- Migration 28: Newsletters (Google Drive link based)

CREATE TABLE public.newsletters (
  id           uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id    uuid    REFERENCES public.schools(id),  -- null = admin/สพป.
  title        text    NOT NULL,
  description  text,
  drive_url    text    NOT NULL,   -- original share link จาก Google Drive
  file_id      text,               -- extracted file ID
  category     text    NOT NULL DEFAULT 'newsletter',
    -- newsletter | announcement | circular | policy | other
  academic_year text,
  month        int,
  year         int,
  is_published boolean NOT NULL DEFAULT false,
  created_by   uuid    REFERENCES public.profiles(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON public.newsletters (school_id);
CREATE INDEX ON public.newsletters (year, month);
CREATE INDEX ON public.newsletters (category);

ALTER TABLE public.newsletters ENABLE ROW LEVEL SECURITY;

-- ทุกคนอ่าน published
CREATE POLICY "newsletters: public read"
  ON public.newsletters FOR SELECT TO anon, authenticated
  USING (is_published = true OR EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid()
    AND role IN ('super_admin','admin','supervisor','staff')
  ) OR EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.school_id = newsletters.school_id
  ));

-- school/admin จัดการได้
CREATE POLICY "newsletters: write"
  ON public.newsletters FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
            AND role IN ('super_admin','admin','supervisor','staff'))
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.school_id = newsletters.school_id
    )
  );
