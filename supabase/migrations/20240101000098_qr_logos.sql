-- Migration 98: คลังโลโก้กลาง QR Code (เฉพาะผู้ล็อกอิน)
-- scope 'area'   = โลโก้ของเขต  → แอดมินเพิ่ม/ลบ, ผู้ล็อกอินทุกคนเลือกใช้ได้
-- scope 'school' = โลโก้โรงเรียน → แอดมินหรือผู้ใช้ของโรงเรียนนั้นเพิ่ม/ลบ, เห็นเฉพาะของโรงเรียนตัวเอง
--                                   (แอดมิน/ศน./เจ้าหน้าที่เห็นทุกโรงเรียน)
-- ภาพเก็บเป็น data URL PNG ที่ย่อแล้ว (≤256px) ในตารางเลย ไม่ใช้ Storage → ไม่ต้องมี policy ของ bucket เพิ่ม
-- is_default = โลโก้เริ่มต้นของ scope นั้น (เขต 1 อัน / โรงเรียนละ 1 อัน) หน้า /qrcode ใส่ให้อัตโนมัติ

CREATE TABLE IF NOT EXISTS public.qr_logos (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope       text NOT NULL CHECK (scope IN ('area','school')),
  school_id   uuid REFERENCES public.schools(id) ON DELETE CASCADE,
  name        text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  image_data  text NOT NULL CHECK (image_data LIKE 'data:image/png;base64,%' AND char_length(image_data) <= 400000),
  is_default  boolean NOT NULL DEFAULT false,
  created_by  uuid DEFAULT auth.uid(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT qr_logos_scope_school CHECK ((scope = 'area' AND school_id IS NULL) OR (scope = 'school' AND school_id IS NOT NULL))
);

CREATE UNIQUE INDEX IF NOT EXISTS qr_logos_one_default_area
  ON public.qr_logos ((true)) WHERE scope = 'area' AND is_default;
CREATE UNIQUE INDEX IF NOT EXISTS qr_logos_one_default_school
  ON public.qr_logos (school_id) WHERE scope = 'school' AND is_default;

ALTER TABLE public.qr_logos ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.qr_logos FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.qr_logos TO authenticated;

-- ผู้ใช้ที่ "จัดการได้": แอดมิน (ทุกอย่าง) หรือผู้ใช้ที่ผูกกับโรงเรียนนั้น
CREATE OR REPLACE FUNCTION public.qr_logo_can_manage(p_scope text, p_school uuid)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (p.role IN ('super_admin','admin')
           OR (p_scope = 'school' AND p.school_id IS NOT NULL AND p.school_id = p_school))
  )
$$;

CREATE OR REPLACE FUNCTION public.qr_logo_can_read(p_scope text, p_school uuid)
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (p_scope = 'area'
           OR p.role IN ('super_admin','admin','supervisor','staff')
           OR (p.school_id IS NOT NULL AND p.school_id = p_school))
  )
$$;

REVOKE ALL ON FUNCTION public.qr_logo_can_manage(text, uuid), public.qr_logo_can_read(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.qr_logo_can_manage(text, uuid), public.qr_logo_can_read(text, uuid) TO authenticated;

DROP POLICY IF EXISTS qr_logos_select ON public.qr_logos;
DROP POLICY IF EXISTS qr_logos_insert ON public.qr_logos;
DROP POLICY IF EXISTS qr_logos_update ON public.qr_logos;
DROP POLICY IF EXISTS qr_logos_delete ON public.qr_logos;

CREATE POLICY qr_logos_select ON public.qr_logos FOR SELECT TO authenticated
  USING (public.qr_logo_can_read(scope, school_id));
CREATE POLICY qr_logos_insert ON public.qr_logos FOR INSERT TO authenticated
  WITH CHECK (public.qr_logo_can_manage(scope, school_id));
CREATE POLICY qr_logos_update ON public.qr_logos FOR UPDATE TO authenticated
  USING (public.qr_logo_can_manage(scope, school_id))
  WITH CHECK (public.qr_logo_can_manage(scope, school_id));
CREATE POLICY qr_logos_delete ON public.qr_logos FOR DELETE TO authenticated
  USING (public.qr_logo_can_manage(scope, school_id));
