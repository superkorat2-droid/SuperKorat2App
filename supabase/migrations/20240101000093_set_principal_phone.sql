-- Migration 93: ให้ ศน./เจ้าหน้าที่/แอดมิน เพิ่ม-แก้-ลบ "เฉพาะเบอร์โทร" ของผู้บริหารได้
-- (นโยบายเขียนของตารางเปิดให้แค่แอดมิน/โรงเรียนเจ้าของ จึงทำเป็น RPC ที่แตะได้คอลัมน์ phone คอลัมน์เดียว)
CREATE OR REPLACE FUNCTION public.set_principal_phone(p_id uuid, p_phone text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v text := NULLIF(regexp_replace(COALESCE(p_phone, ''), '\D', '', 'g'), '');
BEGIN
  IF NOT EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
                 AND role IN ('super_admin','admin','supervisor','staff')) THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์แก้ไขเบอร์โทร' USING ERRCODE = '42501';
  END IF;
  IF v IS NOT NULL AND v !~ '^0\d{8,9}$' THEN
    RAISE EXCEPTION 'เบอร์โทรไม่ถูกต้อง (ต้องขึ้นต้น 0 และมี 9-10 หลัก)' USING ERRCODE = '22023';
  END IF;
  UPDATE school_principals SET phone = v, updated_at = now() WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'ไม่พบผู้บริหาร'; END IF;
  RETURN v;
END $$;

REVOKE ALL ON FUNCTION public.set_principal_phone(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_principal_phone(uuid, text) TO authenticated;
