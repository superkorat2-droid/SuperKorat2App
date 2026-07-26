-- ═══════════════════════════════════════════════════════════════════════
-- personnel_public — แหล่งข้อมูลบุคลากรสาธารณะเพียงแหล่งเดียว
--
-- ปัญหาที่แก้: policy "profiles public read" เป็น SELECT USING (true) และ anon
-- มี SELECT ระดับตารางเต็ม → ใครก็ยิง REST ด้วย anon key ดูด phone/email/line_id
-- ของบุคลากรทุกคนได้ ทั้งที่หน้าเว็บเคารพ contact_visibility อยู่
-- (การซ่อนอยู่ที่ frontend เท่านั้น ฐานข้อมูลไม่เคยบังคับ)
--
-- วิธีแก้ 2 ชั้น:
--   1. view personnel_public — ปิดช่องทางติดต่อตาม contact_visibility ที่ระดับ DB
--   2. ตัดสิทธิ์คอลัมน์อ่อนไหวของ anon บนตาราง profiles ด้วย column-level GRANT
--      → anon อ่านช่องทางติดต่อได้ทางเดียวคือผ่าน view ที่กรองแล้ว
--
-- view ไม่ได้ตั้ง security_invoker จึงรันด้วยสิทธิ์เจ้าของ (postgres) ข้าม RLS
-- และข้าม column grant ของ anon ได้ตามต้องการ
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1. view สาธารณะ ────────────────────────────────────────────────────
-- ตั้งใจไม่กรอง is_active เพื่อไม่เปลี่ยนพฤติกรรมหน้าเดิม (PersonnelView ก็ไม่กรอง)
-- role กรองไว้ 4 บทบาทของบุคลากรเขต — หน้าที่เรียกยังกรองซ้ำเองได้ตามเดิม
CREATE OR REPLACE VIEW public.personnel_public AS
  SELECT
    p.id, p.role, p.org_role,
    p.full_name, p.first_name, p.last_name, p.title,
    p.position, p.position_level, p.department,
    p.subjects, p.expertise, p.bio, p.avatar_url, p.sort_order,
    p.responsibility_area, p.subject_group, p.work_group, p.school_name,

    -- ช่องทางติดต่อ: คืน NULL ถ้าเจ้าตัวตั้ง contact_visibility.<key> = false
    -- (คีย์ที่ไม่มีใน jsonb ถือว่าแสดง — ตรงกับ vis[k] !== false ใน PersonnelView)
    CASE WHEN p.contact_visibility->>'phone'   IS DISTINCT FROM 'false' THEN p.phone   END AS phone,
    CASE WHEN p.contact_visibility->>'email'   IS DISTINCT FROM 'false' THEN p.email   END AS email,
    CASE WHEN p.contact_visibility->>'line_id' IS DISTINCT FROM 'false' THEN p.line_id END AS line_id,

    CASE WHEN p.contact_visibility->>'facebook_url'     IS DISTINCT FROM 'false' THEN p.facebook_url     END AS facebook_url,
    CASE WHEN p.contact_visibility->>'youtube_url'      IS DISTINCT FROM 'false' THEN p.youtube_url      END AS youtube_url,
    CASE WHEN p.contact_visibility->>'tiktok_url'       IS DISTINCT FROM 'false' THEN p.tiktok_url       END AS tiktok_url,
    CASE WHEN p.contact_visibility->>'twitter_url'      IS DISTINCT FROM 'false' THEN p.twitter_url      END AS twitter_url,
    CASE WHEN p.contact_visibility->>'instagram_url'    IS DISTINCT FROM 'false' THEN p.instagram_url    END AS instagram_url,
    CASE WHEN p.contact_visibility->>'linkedin_url'     IS DISTINCT FROM 'false' THEN p.linkedin_url     END AS linkedin_url,
    CASE WHEN p.contact_visibility->>'personal_website' IS DISTINCT FROM 'false' THEN p.personal_website END AS personal_website,
    CASE WHEN p.contact_visibility->>'portfolio_url'    IS DISTINCT FROM 'false' THEN p.portfolio_url    END AS portfolio_url,

    p.contact_visibility,

    -- คงไว้ให้หน้าเดิมกรองได้เหมือนเคย (PersonnelView กรอง is_active + is_approved)
    -- ไม่ใช่ข้อมูลอ่อนไหวเท่าช่องทางติดต่อ และการกรองต้องมีสิทธิ์อ่านคอลัมน์นั้น
    p.is_active, p.is_approved
  FROM public.profiles p
  WHERE p.role IN ('super_admin', 'admin', 'supervisor', 'staff');

GRANT SELECT ON public.personnel_public TO anon, authenticated;

-- ── 2. จำกัดคอลัมน์ที่ anon อ่านได้บนตาราง profiles ────────────────────
-- ตัดออก: email, phone, line_id, social urls (ต้องผ่าน view ที่กรองแล้ว)
--          teacher_code, is_admin, is_active, is_approved, approved_at,
--          approved_by, reject_reason, last_login_at,
--          can_publish_supervision, can_manage_documents (ข้อมูลภายในระบบ)
-- คงไว้: role — จำเป็นเพราะหน้าเดิมกรอง .in('role', …) และการกรองต้องมีสิทธิ์อ่านคอลัมน์นั้น
REVOKE SELECT ON public.profiles FROM anon;

GRANT SELECT (
  id, role, org_role,
  full_name, first_name, last_name, title,
  position, position_level, department,
  subjects, expertise, bio, avatar_url, sort_order,
  responsibility_area, subject_group, work_group,
  school_id, school_name,
  contact_visibility, created_at
) ON public.profiles TO anon;

-- authenticated/service_role ไม่แตะ — RLS policy เดิมคุมอยู่แล้ว

NOTIFY pgrst, 'reload schema';
