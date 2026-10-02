-- Migration 92: ปิดช่องเบอร์โทรผู้บริหารรั่วทาง API + RPC สำหรับหน้าสาธารณะ
--
-- ปัญหาเดิม: school_principals มี SELECT ... USING (true) ให้ anon
--   → ใครเรียก REST API ตรงก็ได้ phone/email/line ทุกคนแม้ visibility = false
--     (หน้าเว็บแค่ซ่อนด้วย v-if)
-- แก้: ตารางอ่านได้เฉพาะ ศน./เจ้าหน้าที่/แอดมิน + โรงเรียนเจ้าของ
--      หน้าสาธารณะอ่านผ่าน RPC ที่ปิดช่องที่ผู้บริหารไม่ได้เปิดให้เป็น NULL

DROP POLICY IF EXISTS "principals: read all" ON public.school_principals;

CREATE POLICY "principals: read staff or own school"
  ON public.school_principals FOR SELECT TO authenticated
  USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid()
              AND role IN ('super_admin','admin','supervisor','staff'))
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.school_id = school_principals.school_id)
  );

REVOKE SELECT ON public.school_principals FROM anon;

-- ผู้บริหารที่แสดงบนหน้าสาธารณะ — เบอร์/อีเมล/ไลน์ออกเฉพาะที่ visibility เป็น true
-- คืน jsonb array หน้าตาเหมือน select('*, schools(...)') เดิม หน้าเว็บแก้น้อยที่สุด
CREATE OR REPLACE FUNCTION public.public_school_principals(p_school_id uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id',         p.id,
    'school_id',  p.school_id,
    'name',       p.name,
    'position',   p.position,
    'photo_url',  p.photo_url,
    'sort_order', p.sort_order,
    'visibility', p.visibility,
    'phone',      CASE WHEN p.visibility->>'phone' = 'true' THEN p.phone   END,
    'email',      CASE WHEN p.visibility->>'email' = 'true' THEN p.email   END,
    'line_id',    CASE WHEN p.visibility->>'line'  = 'true' THEN p.line_id END,
    'schools',    jsonb_build_object('id', s.id, 'name', s.name,
                                     'district', s.district, 'school_group', s.school_group)
  ) ORDER BY p.sort_order), '[]'::jsonb)
  FROM public.school_principals p
  JOIN public.schools s ON s.id = p.school_id
  WHERE p_school_id IS NULL OR p.school_id = p_school_id;
$$;

REVOKE ALL ON FUNCTION public.public_school_principals(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.public_school_principals(uuid) TO anon, authenticated;
