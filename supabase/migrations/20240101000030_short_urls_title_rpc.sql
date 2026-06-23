-- Migration 30: Short URLs — title field + public redirect RPC

-- ── short_urls: เพิ่มชื่อเรื่อง ───────────────────────────────────────────────
ALTER TABLE public.short_urls ADD COLUMN IF NOT EXISTS title text;

-- ── resolve_short_url: ใช้กับหน้า redirect /s/:slug (public, ไม่ต้อง login) ──
-- RLS ของ short_urls อ่านได้เฉพาะ staff ขึ้นไป ดังนั้นการ resolve ลิงค์สำหรับ
-- ผู้ใช้ทั่วไปที่กดลิงค์หรือสแกน QR ต้องผ่าน SECURITY DEFINER แทนการ select ตรง
CREATE OR REPLACE FUNCTION public.resolve_short_url(p_slug text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target text;
BEGIN
  UPDATE public.short_urls
  SET click_count = click_count + 1
  WHERE slug = p_slug
    AND is_active = true
    AND (expires_at IS NULL OR expires_at > now())
  RETURNING target_url INTO v_target;

  RETURN v_target;
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_short_url(text) TO anon, authenticated;
