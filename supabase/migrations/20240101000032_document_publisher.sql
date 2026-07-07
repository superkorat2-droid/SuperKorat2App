-- Migration 32: publisher info บนเอกสาร + RPC นับดาวน์โหลดสำหรับหน้าสาธารณะ
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='documents' AND column_name='publisher_name') THEN
    ALTER TABLE public.documents ADD COLUMN publisher_name text DEFAULT '';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='documents' AND column_name='publisher_dept') THEN
    ALTER TABLE public.documents ADD COLUMN publisher_dept text DEFAULT '';
  END IF;
END $$;

-- ── RPC: increment download (public /download ต้องอัปเดต download_count โดยไม่มีสิทธิ์ staff) ──
CREATE OR REPLACE FUNCTION public.increment_document_download(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE public.documents SET download_count = download_count + 1
  WHERE id = p_id AND is_published = true;
END;
$$;
GRANT EXECUTE ON FUNCTION public.increment_document_download(uuid) TO anon, authenticated;
