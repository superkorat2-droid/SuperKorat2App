-- ============================================================
-- Seed: Local Development Data
-- สร้าง super_admin user สำหรับ dev local
-- ============================================================

-- ── 1. สร้าง admin user ใน auth.users ────────────────────────
INSERT INTO auth.users (
  id,
  instance_id,
  email,
  encrypted_password,
  email_confirmed_at,
  role,
  aud,
  created_at,
  updated_at,
  raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'admin@local.dev',
  crypt('admin1234', gen_salt('bf')),
  now(),
  'authenticated',
  'authenticated',
  now(),
  now(),
  '{"full_name": "ผู้ดูแลระบบ"}'::jsonb
) ON CONFLICT (id) DO NOTHING;

-- ── 2. upsert profile → super_admin ──────────────────────────
INSERT INTO public.profiles (
  id, email, full_name, role, is_admin, is_approved, is_active, created_at
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'admin@local.dev',
  'ผู้ดูแลระบบ (Local Dev)',
  'super_admin',
  true,
  true,
  true,
  now()
) ON CONFLICT (id) DO UPDATE SET
  role        = 'super_admin',
  is_admin    = true,
  is_approved = true,
  is_active   = true;

-- ── 3. area_config default (korat2 style) ────────────────────
UPDATE public.area_config SET
  area_name       = 'สำนักงานเขตพื้นที่การศึกษาประถมศึกษา (Local Dev)',
  area_name_short = 'สพป.ทดสอบ',
  area_type       = 'สพป.',
  province        = 'ทดสอบ',
  area_number     = '1',
  primary_color   = '#2563eb',
  secondary_color = '#4f46e5'
WHERE id = 1;

-- ── 4. seed news ─────────────────────────────────────────────
INSERT INTO public.news (category, title, excerpt, content, is_pinned, is_published, published_at, created_by)
VALUES
  ('pr', 'ยินดีต้อนรับสู่ระบบทดสอบ Local', 'ระบบ Local Supabase พร้อมใช้งาน',
   'นี่คือข่าวทดสอบสำหรับ local development', true, true, now(),
   '00000000-0000-0000-0000-000000000001'),
  ('supervision', 'ข่าวนิเทศการศึกษาทดสอบ', 'ข่าวทดสอบ', 'เนื้อหาทดสอบ', false, true, now(),
   '00000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

-- ── ✅ Summary ────────────────────────────────────────────────
DO $$ BEGIN
  RAISE NOTICE '✅ Seed complete';
  RAISE NOTICE '   Email   : admin@local.dev';
  RAISE NOTICE '   Password: admin1234';
  RAISE NOTICE '   Role    : super_admin';
END $$;
