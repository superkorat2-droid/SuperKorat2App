-- ============================================================
-- PATCH: สร้าง/เพิ่ม column ตาราง banners (รันซ้ำได้ปลอดภัย)
-- ============================================================

-- ── 1. สร้างตารางถ้ายังไม่มี (skeleton เปล่า) ─────────────────
CREATE TABLE IF NOT EXISTS public.banners (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now()
);

-- ── 2. เพิ่ม column ทีละอัน (ปลอดภัย ไม่ error แม้มีอยู่แล้ว) ──
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='title') THEN
    ALTER TABLE public.banners ADD COLUMN title text DEFAULT '';
    RAISE NOTICE '✅ Added: title'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='subtitle') THEN
    ALTER TABLE public.banners ADD COLUMN subtitle text DEFAULT '';
    RAISE NOTICE '✅ Added: subtitle'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='image_url') THEN
    ALTER TABLE public.banners ADD COLUMN image_url text DEFAULT '';
    RAISE NOTICE '✅ Added: image_url'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='banner_type') THEN
    ALTER TABLE public.banners ADD COLUMN banner_type text DEFAULT 'image';
    RAISE NOTICE '✅ Added: banner_type'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='link_url') THEN
    ALTER TABLE public.banners ADD COLUMN link_url text DEFAULT '';
    RAISE NOTICE '✅ Added: link_url'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='is_active') THEN
    ALTER TABLE public.banners ADD COLUMN is_active boolean DEFAULT true;
    RAISE NOTICE '✅ Added: is_active'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='sort_order') THEN
    ALTER TABLE public.banners ADD COLUMN sort_order int DEFAULT 0;
    RAISE NOTICE '✅ Added: sort_order'; END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='banners' AND column_name='created_by') THEN
    ALTER TABLE public.banners ADD COLUMN created_by uuid REFERENCES public.profiles(id);
    RAISE NOTICE '✅ Added: created_by'; END IF;

  RAISE NOTICE '✅ banners columns done';
END $$;

-- ── 3. RLS Policies ────────────────────────────────────────────
DO $$
BEGIN
  DROP POLICY IF EXISTS "banners public read" ON public.banners;
  DROP POLICY IF EXISTS "banners admin write" ON public.banners;
END $$;

ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

CREATE POLICY "banners public read" ON public.banners FOR SELECT
  USING (
    is_active = true OR EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

CREATE POLICY "banners admin write" ON public.banners FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role IN ('super_admin','admin')
  ));

-- ── 4. Indexes ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_banners_sort_order ON public.banners(sort_order);
CREATE INDEX IF NOT EXISTS idx_banners_active     ON public.banners(is_active);

-- ── ✅ ตรวจสอบ columns ────────────────────────────────────────
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'banners'
ORDER BY ordinal_position;
