-- ═══════════════════════════════════════════════════════════════════════
-- ปิดรูรั่ว: รหัสสมัครสมาชิก + รหัสผ่านเริ่มต้นของโรงเรียน อ่านได้โดยไม่ต้องล็อกอิน
--
-- ยืนยันบน production ด้วย anon key ธรรมดา (ไม่ล็อกอิน) ได้ค่าจริงกลับมาทั้งสามตัว
-- ต่อจิ๊กซอว์เป็นทางเข้าระบบได้: อีเมลบัญชีโรงเรียนก็อ่านได้จากตาราง schools
-- → รู้อีเมล + รู้รหัสผ่านเริ่มต้น = ล็อกอินเป็นโรงเรียนที่ยังไม่เปลี่ยนรหัสได้
-- (วันนี้มีบัญชีโรงเรียนจริง 1 บัญชี แต่ถ้าสร้างครบทั้งเขตจะกลายเป็นประตูเปิดทันที)
--
-- รั่ว 2 ทาง ต้องปิดทั้งคู่:
--   1. RPC get_area_config() คืน row_to_json(a) ทั้งแถว และเป็น SECURITY DEFINER
--      จึงข้าม RLS/column grant ทุกอย่าง  ← ทางที่หน้าเว็บใช้จริง
--   2. anon มี SELECT ระดับตารางบน area_config จึง select คอลัมน์ตรงๆ ได้
--
-- คงไว้ให้ anon อ่านได้: register_code_enabled (หน้าสมัครต้องรู้ว่าจะโชว์ช่องรหัสไหม)
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. RPC สาธารณะ: ตัดคอลัมน์ลับออกก่อนคืนค่า ────────────────────────
-- ส่ง "มี/ไม่มีรหัส" เป็น boolean แทนตัวรหัสจริง เพราะหน้าสมัครต้องรู้ว่าจะโชว์
-- ช่องกรอกรหัสไหม (เดิมมันเช็คจากค่ารหัสตรงๆ ซึ่งเป็นเหตุที่ต้องส่งรหัสไปให้)
CREATE OR REPLACE FUNCTION public.get_area_config()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT (row_to_json(a)::jsonb)
           - 'register_code_teacher'
           - 'register_code_personnel'
           - 'default_school_password'
         || jsonb_build_object(
              'has_register_code_teacher',   COALESCE(btrim(a.register_code_teacher), '')   <> '',
              'has_register_code_personnel', COALESCE(btrim(a.register_code_personnel), '') <> ''
            )
  FROM public.area_config a WHERE id = 1;
$$;

-- ── 2. ตัดสิทธิ์คอลัมน์ลับของ anon บนตัวตาราง ─────────────────────────
-- ไม่แตะ authenticated เพราะหน้าตั้งค่า (select *) และหน้าจัดการโรงเรียนต้องใช้
-- และ authenticated = บัญชีที่ผ่านการอนุมัติของเขตแล้ว ไม่ใช่คนนอก
REVOKE SELECT ON public.area_config FROM anon;

GRANT SELECT (
  id, area_name, area_name_short, area_type, province, area_number,
  logo_url, primary_color, secondary_color, tagline,
  contact_address, contact_phone, contact_fax, contact_email,
  facebook_url, line_url, youtube_url, website_url,
  allow_teacher_register, show_public_stats, show_public_news,
  show_public_works, allow_external_works,
  school_email_domain, updated_at,
  home_sections, banner_bg, banner_bg2, banner_bg_type, banner_aspect_ratio,
  nav_groups, personnel_groups, services, page_headers, task_types,
  home_gallery, footer_extra_title, footer_extra_links,
  schools_page_title, schools_page_subtitle,
  welcome_popup_enabled, welcome_popup_image_url, welcome_popup_link_url,
  register_code_enabled
) ON public.area_config TO anon;

-- ── 3. ตรวจรหัสสมัครสมาชิกที่ฝั่ง DB ──────────────────────────────────
-- เดิมหน้าเว็บโหลดรหัสจริงมาเทียบเองในเบราว์เซอร์ (LoginView) ซึ่งแปลว่า
-- รหัสต้องถูกส่งให้ทุกคน = ไม่เป็นความลับ ตอนนี้ส่งแค่รหัสที่ผู้ใช้กรอกเข้ามา
-- แล้วให้ DB ตอบว่าใช่/ไม่ใช่
--
-- คงพฤติกรรมเดิมไว้ทุกอย่าง (ไม่พ่วงการเปลี่ยน logic มากับงานความปลอดภัย):
--   ปิดสวิตช์            → ผ่าน
--   เปิดแต่รหัสของกลุ่มนั้นว่าง → ผ่าน  ← ยังเป็นกับดักเดิม ดูหมายเหตุท้ายไฟล์
--   เทียบแบบไม่สนตัวพิมพ์เล็กใหญ่และตัดช่องว่างหัวท้าย เหมือนโค้ดเดิม
CREATE OR REPLACE FUNCTION public.verify_register_code(p_role text, p_code text)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_enabled  boolean;
  v_expected text;
BEGIN
  SELECT register_code_enabled,
         CASE WHEN p_role IN ('supervisor','staff')
              THEN register_code_personnel ELSE register_code_teacher END
    INTO v_enabled, v_expected
  FROM public.area_config WHERE id = 1;

  IF NOT COALESCE(v_enabled, false) THEN RETURN true; END IF;
  IF v_expected IS NULL OR btrim(v_expected) = '' THEN RETURN true; END IF;

  RETURN upper(btrim(COALESCE(p_code, ''))) = upper(btrim(v_expected));
END;
$$;

GRANT EXECUTE ON FUNCTION public.verify_register_code(text, text) TO anon, authenticated;

-- ── หมายเหตุที่ยังค้าง (ตั้งใจไม่แก้ในไมเกรชันนี้) ────────────────────
-- 1. "เปิดสวิตช์แต่ปล่อยรหัสว่าง = ไม่มีการตรวจ" ยังเป็นแบบเดิม เพราะข้อความ
--    ในหน้าตั้งค่าเขียนไว้ว่า "ปล่อยว่าง = ไม่ต้องใช้รหัส" การเปลี่ยนให้ fail-closed
--    ต้องแก้ข้อความและแจ้ง user ก่อน ไม่ควรพ่วงมากับงานปิดรูรั่ว
-- 2. RPC นี้กันการ "เดารหัส" ไม่ได้ (ยิงซ้ำได้ไม่จำกัด) แต่ด่านจริงคือ
--    profiles.is_approved = false ตอนสมัคร ซึ่ง RLS ของ works/media บังคับอยู่
-- 3. รหัสทั้งสามตัวที่หลุดไปแล้วถือว่าใช้ไม่ได้อีก ต้องให้ผู้ดูแลตั้งใหม่เอง

NOTIFY pgrst, 'reload schema';
