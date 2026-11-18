-- Migration 103: ปิดช่องโหว่ผู้ใช้แก้สิทธิ์ตัวเอง + สิทธิ์ "ผู้ดูแลแบบนิเทศทั้งหมด" + ค่าเริ่มต้นปุ่มดูสถานะ
-- รันซ้ำได้

-- ─── 1) ปิดช่องโหว่: ผู้ใช้แก้คอลัมน์สิทธิ์ของตัวเอง ─────────────────────────────
-- policy "profiles self update" ให้แก้แถวตัวเองได้ทุกคอลัมน์ → ยิง REST เปลี่ยน role ตัวเองเป็น super_admin ได้
-- (ยืนยันแล้ว 18 พ.ย. 69) trigger นี้คืนค่าเดิมให้คอลัมน์สิทธิ์แบบเงียบ ๆ เมื่อผู้ทำไม่ใช่แอดมิน
-- → หน้าโปรไฟล์ที่ upsert ทั้งแถวยังใช้ได้ (ชื่อ/รูป/เบอร์ แก้ได้ปกติ)
-- คอลัมน์ can_* ทุกช่อง (รวมที่จะเพิ่มในอนาคต) ถูกป้องกันอัตโนมัติด้วยชื่อขึ้นต้น can_
-- ไม่จำกัด: แอดมิน · ระบบ/service role/Edge Function (auth.uid() ว่าง) · trigger สมัครสมาชิก handle_new_user
-- school_id: แก้ได้เฉพาะตอนยังไม่ได้รับอนุมัติ (กันบัญชีโรงเรียนย้ายตัวเองไปเป็นโรงอื่นแล้วส่งแบบแทน)
CREATE OR REPLACE FUNCTION public.guard_profile_privileges()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_keep jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;
  IF public.get_my_role() IN ('super_admin', 'admin') THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    -- แถวใหม่จากผู้ใช้ทั่วไป: สิทธิ์เริ่มต้นเสมอ
    SELECT jsonb_object_agg(key, CASE WHEN key LIKE 'can\_%' THEN 'false'::jsonb ELSE value END)
      INTO v_keep
      FROM jsonb_each(to_jsonb(NEW)) WHERE key LIKE 'can\_%';
    NEW := jsonb_populate_record(NEW, COALESCE(v_keep, '{}'::jsonb)
      || jsonb_build_object('role', 'teacher', 'is_approved', false, 'is_active', true, 'approved_at', NULL));
    RETURN NEW;
  END IF;

  SELECT jsonb_object_agg(key, value)
    INTO v_keep
    FROM jsonb_each(to_jsonb(OLD))
    WHERE key LIKE 'can\_%' OR key IN ('role', 'is_approved', 'is_active', 'approved_at');
  NEW := jsonb_populate_record(NEW, v_keep);
  IF OLD.is_approved THEN NEW.school_id := OLD.school_id; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS guard_profile_privileges ON public.profiles;
CREATE TRIGGER guard_profile_privileges
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_profile_privileges();

-- ─── 2) ผู้ดูแลแบบนิเทศทั้งหมด (ติ๊กรายคนในหน้าจัดการผู้ใช้) ────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_manage_all_supervision boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION public.is_supervision_manager()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND (role IN ('super_admin', 'admin') OR (can_manage_all_supervision AND is_active))
  );
$$;
REVOKE ALL ON FUNCTION public.is_supervision_manager() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_supervision_manager() TO authenticated;

-- policy เดิม (migration 22) + OR is_supervision_manager()
DROP POLICY IF EXISTS "supervision_forms: select" ON public.supervision_forms;
CREATE POLICY "supervision_forms: select" ON public.supervision_forms
  FOR SELECT USING (
    public.is_supervision_manager()
    OR created_by = auth.uid()
    OR (status = 'published' AND auth.role() = 'authenticated')
  );

DROP POLICY IF EXISTS "supervision_forms: update" ON public.supervision_forms;
CREATE POLICY "supervision_forms: update" ON public.supervision_forms
  FOR UPDATE USING (
    public.is_supervision_manager()
    OR (created_by = auth.uid() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('supervisor', 'staff')))
  );

DROP POLICY IF EXISTS "supervision_forms: delete" ON public.supervision_forms;
CREATE POLICY "supervision_forms: delete" ON public.supervision_forms
  FOR DELETE USING (
    public.is_supervision_manager()
    OR (created_by = auth.uid() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('supervisor', 'staff')))
  );

-- แก้คำตอบ/ปลดล็อก (migration 99) + ผู้ดูแลแบบนิเทศ
CREATE OR REPLACE FUNCTION public.can_manage_supervision_form(p_form_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT public.is_supervision_manager()
      OR EXISTS (SELECT 1 FROM public.supervision_forms f
                 WHERE f.id = p_form_id
                   AND (f.created_by = auth.uid() OR auth.uid() = ANY (f.responsible_ids)));
$$;

-- ─── 3) ปุ่ม "ดูสถานะโรงเรียน" ในหน้าแรก: แบบใหม่เปิดเป็นสาธารณะ (แบบเดิมไม่เปลี่ยน) ────
ALTER TABLE public.supervision_forms ALTER COLUMN status_visibility SET DEFAULT 'public';
