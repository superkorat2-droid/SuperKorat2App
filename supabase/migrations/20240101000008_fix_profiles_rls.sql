-- ============================================================
-- Migration 8: Fix infinite recursion in profiles RLS
-- ปัญหา: policy "profiles admin manage" query profiles จาก
--         ภายใน policy ของ profiles เอง → infinite recursion
-- แก้: ใช้ SECURITY DEFINER function ตัดวงจร
-- ============================================================

-- helper function: อ่าน role โดยตรง ข้าม RLS
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.profiles WHERE id = auth.uid();
$$;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated, anon;

-- แก้ policy ที่ recursive
DROP POLICY IF EXISTS "profiles admin manage" ON public.profiles;
CREATE POLICY "profiles admin manage"
  ON public.profiles FOR ALL
  USING (public.get_my_role() IN ('super_admin', 'admin'));

-- แก้ policies อื่นที่ query profiles จาก profiles (ป้องกันไว้ก่อน)
DROP POLICY IF EXISTS "profiles: users read all"   ON public.profiles;
DROP POLICY IF EXISTS "profiles: users update own" ON public.profiles;
DROP POLICY IF EXISTS "profiles public read"       ON public.profiles;
DROP POLICY IF EXISTS "profiles self update"       ON public.profiles;

CREATE POLICY "profiles public read"
  ON public.profiles FOR SELECT USING (true);

CREATE POLICY "profiles self update"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);
