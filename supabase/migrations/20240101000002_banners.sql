-- ============================================================
-- Migration 2: Banners table + v2 additions
-- ============================================================

-- ── banners base table + columns ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.banners (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now()
);

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='title') THEN
    ALTER TABLE public.banners ADD COLUMN title text DEFAULT ''; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='subtitle') THEN
    ALTER TABLE public.banners ADD COLUMN subtitle text DEFAULT ''; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='image_url') THEN
    ALTER TABLE public.banners ADD COLUMN image_url text DEFAULT ''; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='banner_type') THEN
    ALTER TABLE public.banners ADD COLUMN banner_type text DEFAULT 'image'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='link_url') THEN
    ALTER TABLE public.banners ADD COLUMN link_url text DEFAULT ''; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='is_active') THEN
    ALTER TABLE public.banners ADD COLUMN is_active boolean DEFAULT true; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='sort_order') THEN
    ALTER TABLE public.banners ADD COLUMN sort_order int DEFAULT 0; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='created_by') THEN
    ALTER TABLE public.banners ADD COLUMN created_by uuid REFERENCES public.profiles(id); END IF;
  -- v2 additions
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='is_pinned') THEN
    ALTER TABLE public.banners ADD COLUMN is_pinned boolean NOT NULL DEFAULT false; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='link_type') THEN
    ALTER TABLE public.banners ADD COLUMN link_type text NOT NULL DEFAULT 'none'; END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='description') THEN
    ALTER TABLE public.banners ADD COLUMN description text NOT NULL DEFAULT ''; END IF;
END $$;

-- ── RLS ───────────────────────────────────────────────────────
DROP POLICY IF EXISTS "banners public read" ON public.banners;
DROP POLICY IF EXISTS "banners admin write" ON public.banners;

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "banners public read" ON public.banners FOR SELECT
  USING (
    is_active = true OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

CREATE POLICY "banners admin write" ON public.banners FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('super_admin','admin')
  ));

-- ── Indexes ───────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_banners_sort_order ON public.banners(sort_order);
CREATE INDEX IF NOT EXISTS idx_banners_active     ON public.banners(is_active);
