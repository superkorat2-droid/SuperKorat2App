-- Migration 29: Media Library

-- ── media: ตารางหลัก ──────────────────────────────────────────────────────────
CREATE TABLE public.media (
  id              uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  title           text    NOT NULL,
  description     text,
  content_blocks  jsonb   DEFAULT '[]',   -- block editor (heading/text/image/embed/html/drive)
  media_type      text    NOT NULL,       -- book|video|image|audio|app|exam|template|multimedia

  -- แหล่งสื่อหลัก (เลือกได้)
  drive_url       text,
  file_id         text,                  -- Drive file ID
  embed_url       text,                  -- YouTube/embed URL
  external_url    text,                  -- ลิงก์ภายนอก
  thumbnail_url   text,

  -- หมวดหมู่
  subject_group   text,
  grade_levels    text[] DEFAULT '{}',
  education_level text    DEFAULT 'general', -- primary|secondary|both|general
  tags            text[]  DEFAULT '{}',

  -- เจ้าของ
  school_id       uuid    REFERENCES public.schools(id),
  created_by      uuid    REFERENCES public.profiles(id),
  author_name     text,

  -- สถิติ (denormalized)
  view_count      int     NOT NULL DEFAULT 0,
  like_count      int     NOT NULL DEFAULT 0,
  download_count  int     NOT NULL DEFAULT 0,

  -- สถานะ
  is_published    boolean NOT NULL DEFAULT false,
  is_featured     boolean NOT NULL DEFAULT false,
  is_approved     boolean NOT NULL DEFAULT true,  -- false สำหรับ teacher → ต้อง admin approve

  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ON public.media (media_type);
CREATE INDEX ON public.media (is_published, is_approved);
CREATE INDEX ON public.media (created_by);
CREATE INDEX ON public.media (view_count DESC);
CREATE INDEX ON public.media (like_count DESC);

-- ── media_likes ───────────────────────────────────────────────────────────────
CREATE TABLE public.media_likes (
  id         uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  media_id   uuid    NOT NULL REFERENCES public.media(id) ON DELETE CASCADE,
  user_id    uuid    REFERENCES public.profiles(id),
  ip_hash    text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(media_id, user_id),
  CONSTRAINT media_likes_anon UNIQUE NULLS NOT DISTINCT (media_id, ip_hash)
);

-- ── media_views ───────────────────────────────────────────────────────────────
CREATE TABLE public.media_views (
  id         uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  media_id   uuid    NOT NULL REFERENCES public.media(id) ON DELETE CASCADE,
  user_id    uuid    REFERENCES public.profiles(id),
  session_id text,
  viewed_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(media_id, session_id)
);

-- ── RLS ───────────────────────────────────────────────────────────────────────
ALTER TABLE public.media       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_views ENABLE ROW LEVEL SECURITY;

-- media: ทุกคนอ่าน published+approved | เจ้าของอ่านของตัวเอง | admin อ่านทั้งหมด
CREATE POLICY "media: read"
  ON public.media FOR SELECT
  USING (
    (is_published = true AND is_approved = true)
    OR auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
               AND role IN ('super_admin','admin','supervisor','staff'))
  );

-- media: write สำหรับ authenticated
CREATE POLICY "media: write"
  ON public.media FOR ALL
  USING (
    auth.uid() = created_by
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()
               AND role IN ('super_admin','admin'))
  );

-- likes: ทุกคน insert/read
CREATE POLICY "media_likes: all" ON public.media_likes FOR ALL TO anon, authenticated USING (true);
CREATE POLICY "media_views: all" ON public.media_views FOR ALL TO anon, authenticated USING (true);

-- ── RPC: บันทึก view ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.record_media_view(p_media_id uuid, p_session_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO public.media_views (media_id, user_id, session_id)
  VALUES (p_media_id, auth.uid(), p_session_id)
  ON CONFLICT (media_id, session_id) DO NOTHING;

  IF FOUND THEN
    UPDATE public.media SET view_count = view_count + 1 WHERE id = p_media_id;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_media_view(uuid, text) TO anon, authenticated;

-- ── RPC: toggle like ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.toggle_media_like(p_media_id uuid, p_ip_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_liked   boolean;
BEGIN
  IF v_user_id IS NOT NULL THEN
    -- authenticated: track by user_id
    IF EXISTS (SELECT 1 FROM public.media_likes WHERE media_id = p_media_id AND user_id = v_user_id) THEN
      DELETE FROM public.media_likes WHERE media_id = p_media_id AND user_id = v_user_id;
      UPDATE public.media SET like_count = GREATEST(0, like_count - 1) WHERE id = p_media_id;
      v_liked := false;
    ELSE
      INSERT INTO public.media_likes (media_id, user_id) VALUES (p_media_id, v_user_id);
      UPDATE public.media SET like_count = like_count + 1 WHERE id = p_media_id;
      v_liked := true;
    END IF;
  ELSE
    -- anonymous: track by IP hash
    IF EXISTS (SELECT 1 FROM public.media_likes WHERE media_id = p_media_id AND ip_hash = p_ip_hash AND user_id IS NULL) THEN
      DELETE FROM public.media_likes WHERE media_id = p_media_id AND ip_hash = p_ip_hash AND user_id IS NULL;
      UPDATE public.media SET like_count = GREATEST(0, like_count - 1) WHERE id = p_media_id;
      v_liked := false;
    ELSE
      INSERT INTO public.media_likes (media_id, ip_hash) VALUES (p_media_id, p_ip_hash);
      UPDATE public.media SET like_count = like_count + 1 WHERE id = p_media_id;
      v_liked := true;
    END IF;
  END IF;

  RETURN jsonb_build_object('liked', v_liked,
    'like_count', (SELECT like_count FROM public.media WHERE id = p_media_id));
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_media_like(uuid, text) TO anon, authenticated;

-- ── RPC: increment download ───────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.increment_media_download(p_media_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.media SET download_count = download_count + 1 WHERE id = p_media_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.increment_media_download(uuid) TO anon, authenticated;
