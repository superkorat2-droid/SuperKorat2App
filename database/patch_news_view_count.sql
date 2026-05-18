-- patch_news_view_count.sql
-- เพิ่ม view_count ใน news + RPC increment (ปลอดภัยรันซ้ำ)

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'news' AND column_name = 'view_count'
  ) THEN
    ALTER TABLE public.news ADD COLUMN view_count integer NOT NULL DEFAULT 0;
  END IF;
END $$;

-- RPC: นับยอดอ่าน +1 (เรียกได้โดยไม่ต้อง login)
CREATE OR REPLACE FUNCTION public.increment_news_view(news_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER AS $$
  UPDATE public.news
  SET view_count = view_count + 1
  WHERE id = news_id AND is_published = true;
$$;
GRANT EXECUTE ON FUNCTION public.increment_news_view(uuid) TO anon, authenticated;
