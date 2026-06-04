-- Migration 12: Personnel extended fields
DO $$ BEGIN

  -- ── ชื่อแยก ────────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='title') THEN
    ALTER TABLE public.profiles ADD COLUMN title text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='first_name') THEN
    ALTER TABLE public.profiles ADD COLUMN first_name text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='last_name') THEN
    ALTER TABLE public.profiles ADD COLUMN last_name text DEFAULT '';
  END IF;

  -- ── ตำแหน่งในองค์กร ────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='org_role') THEN
    ALTER TABLE public.profiles ADD COLUMN org_role text DEFAULT 'staff'
      CHECK (org_role IN ('director','deputy','group_director','supervisor','staff','other'));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='department') THEN
    ALTER TABLE public.profiles ADD COLUMN department text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='position_level') THEN
    ALTER TABLE public.profiles ADD COLUMN position_level text DEFAULT '';
  END IF;

  -- ── ความเชี่ยวชาญ ──────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='subjects') THEN
    ALTER TABLE public.profiles ADD COLUMN subjects text[] DEFAULT '{}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='expertise') THEN
    ALTER TABLE public.profiles ADD COLUMN expertise text[] DEFAULT '{}';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='bio') THEN
    ALTER TABLE public.profiles ADD COLUMN bio text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='sort_order') THEN
    ALTER TABLE public.profiles ADD COLUMN sort_order int DEFAULT 99;
  END IF;

  -- ── Social Media ────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='facebook_url') THEN
    ALTER TABLE public.profiles ADD COLUMN facebook_url text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='youtube_url') THEN
    ALTER TABLE public.profiles ADD COLUMN youtube_url text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='tiktok_url') THEN
    ALTER TABLE public.profiles ADD COLUMN tiktok_url text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='twitter_url') THEN
    ALTER TABLE public.profiles ADD COLUMN twitter_url text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='instagram_url') THEN
    ALTER TABLE public.profiles ADD COLUMN instagram_url text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='linkedin_url') THEN
    ALTER TABLE public.profiles ADD COLUMN linkedin_url text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='personal_website') THEN
    ALTER TABLE public.profiles ADD COLUMN personal_website text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='portfolio_url') THEN
    ALTER TABLE public.profiles ADD COLUMN portfolio_url text DEFAULT '';
  END IF;

  -- ── Visibility settings (JSONB) ────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='profiles' AND column_name='contact_visibility') THEN
    ALTER TABLE public.profiles ADD COLUMN contact_visibility jsonb DEFAULT '{
      "phone": false,
      "email": false,
      "line_id": false,
      "facebook_url": true,
      "youtube_url": true,
      "tiktok_url": true,
      "twitter_url": true,
      "instagram_url": true,
      "linkedin_url": true,
      "personal_website": true,
      "portfolio_url": true
    }'::jsonb;
  END IF;

END $$;

-- Index สำหรับ query ทำเนียบ
CREATE INDEX IF NOT EXISTS idx_profiles_org_role  ON public.profiles(org_role);
CREATE INDEX IF NOT EXISTS idx_profiles_sort_order ON public.profiles(sort_order);
