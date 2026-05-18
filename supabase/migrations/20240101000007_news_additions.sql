-- ============================================================
-- Migration 7: news table additions
-- html_code + embed columns + view_count
-- ============================================================

DO $$ BEGIN
  -- html_code
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='news' AND column_name='html_code') THEN
    ALTER TABLE public.news ADD COLUMN html_code text NOT NULL DEFAULT '';
  END IF;
  -- embed_url
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='news' AND column_name='embed_url') THEN
    ALTER TABLE public.news ADD COLUMN embed_url text NOT NULL DEFAULT '';
  END IF;
  -- embed_type
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='news' AND column_name='embed_type') THEN
    ALTER TABLE public.news ADD COLUMN embed_type text NOT NULL DEFAULT '';
  END IF;
  -- show_cover
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='news' AND column_name='show_cover') THEN
    ALTER TABLE public.news ADD COLUMN show_cover boolean NOT NULL DEFAULT true;
  END IF;
  -- show_title
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='news' AND column_name='show_title') THEN
    ALTER TABLE public.news ADD COLUMN show_title boolean NOT NULL DEFAULT true;
  END IF;
  -- view_count
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='news' AND column_name='view_count') THEN
    ALTER TABLE public.news ADD COLUMN view_count integer NOT NULL DEFAULT 0;
  END IF;
END $$;

-- RPC: increment view count (anon ใช้ได้)
CREATE OR REPLACE FUNCTION public.increment_news_view(news_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.news
  SET view_count = view_count + 1
  WHERE id = news_id AND is_published = true;
$$;
GRANT EXECUTE ON FUNCTION public.increment_news_view(uuid) TO anon, authenticated;
