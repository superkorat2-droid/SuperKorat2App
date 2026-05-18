-- ============================================================
-- Migration 0: Initial Schema
-- profiles (base) + contents
-- handle_new_user trigger จะถูกสร้างใน migration 1
-- ============================================================

-- ── profiles (base table) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.profiles (
  id                  uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email               text UNIQUE NOT NULL DEFAULT '',
  full_name           text NOT NULL DEFAULT '',
  avatar_url          text DEFAULT '',
  position            text DEFAULT '',
  responsibility_area text DEFAULT '',
  is_admin            boolean DEFAULT false,
  created_at          timestamptz DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles: users read all"
  ON public.profiles FOR SELECT USING (true);
CREATE POLICY "profiles: users update own"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- ── is_admin() helper (ใช้โดย setup.sql legacy) ──────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN COALESCE(
    (SELECT is_admin FROM public.profiles WHERE id = auth.uid()),
    false
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── contents (supervisor content) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.contents (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  content_type   text NOT NULL DEFAULT 'News',
  title          text NOT NULL DEFAULT '',
  file_url       text DEFAULT '',
  is_published   boolean DEFAULT true,
  created_at     timestamptz DEFAULT now()
);

ALTER TABLE public.contents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "contents: public read published"
  ON public.contents FOR SELECT USING (is_published = true);
CREATE POLICY "contents: admin manage"
  ON public.contents FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_admin = true
  ));
