-- Migration 94: จำกัดการเพิ่ม/แก้/ลบเบอร์ผู้บริหารให้เฉพาะแอดมิน (ศน./เจ้าหน้าที่ดูและโทรได้อย่างเดียว)
-- เปลี่ยนเฉพาะเงื่อนไขสิทธิ์ของฟังก์ชันจาก 0093 — ไม่แตะข้อมูล
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
                 AND role IN ('super_admin','admin')) THEN
    RAISE EXCEPTION 'เฉพาะแอดมินเท่านั้นที่แก้ไขเบอร์โทรได้' USING ERRCODE = '42501';
  END IF;
  IF v IS NOT NULL AND v !~ '^0\d{8,9}$' THEN
    RAISE EXCEPTION 'เบอร์โทรไม่ถูกต้อง (ต้องขึ้นต้น 0 และมี 9-10 หลัก)' USING ERRCODE = '22023';
  END IF;
  UPDATE school_principals SET phone = v, updated_at = now() WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'ไม่พบผู้บริหาร'; END IF;
  RETURN v;
END $$;
