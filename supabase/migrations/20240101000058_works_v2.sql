-- ระบบเผยแพร่ผลงาน (works) — เติมให้ใช้งานได้จริง
--
-- ตาราง works มีมาตั้งแต่ v2_core แล้ว (work_type/owner_type/status/approved_by/
-- reject_reason) แต่ไม่เคยมีหน้าจอ และยังขาด block editor + สถิติ เทียบกับคลังสื่อ
--
-- แยกจาก media โดยตั้งใจ: สื่อ = ของใช้สอน เผยแพร่ได้เลย · ผลงาน = ให้เครดิตเจ้าของ
-- ต้องผ่านการอนุมัติ — คนละ metadata คนละ lifecycle

-- ── 1. ขยายตาราง ────────────────────────────────────────────
ALTER TABLE public.works
  ADD COLUMN IF NOT EXISTS content_blocks  jsonb       NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS school_id       uuid        REFERENCES public.schools(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS subject_group   text        NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS grade_levels    text[]      NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS academic_year   text        NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS view_count      int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS like_count      int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS download_count  int         NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_featured     boolean     NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS published_at    timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at      timestamptz NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS works_status_idx     ON public.works(status);
CREATE INDEX IF NOT EXISTS works_owner_idx      ON public.works(owner_id);
CREATE INDEX IF NOT EXISTS works_type_idx       ON public.works(work_type);
CREATE INDEX IF NOT EXISTS works_view_count_idx ON public.works(view_count DESC);

DROP TRIGGER IF EXISTS works_updated_at ON public.works;
CREATE TRIGGER works_updated_at
  BEFORE UPDATE ON public.works
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 2. สถานะตามบทบาท — บังคับที่ DB ห้ามเชื่อค่าจาก client ────
-- บุคลากรเขต (ศน./เจ้าหน้าที่/admin) เผยแพร่ได้ทันที
-- ครู/โรงเรียน ต้องรออนุมัติ
-- ถ้าไม่บังคับตรงนี้ client ยิง status='approved' มาเองได้เลย
CREATE OR REPLACE FUNCTION public.works_before_insert()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_role text;
BEGIN
  -- กันสร้างแล้วสวมชื่อคนอื่น — แต่ถ้าไม่มี JWT (service role / seed script)
  -- ให้เคารพค่าที่ส่งมา ไม่งั้นจะติด NOT NULL
  IF auth.uid() IS NOT NULL THEN NEW.owner_id := auth.uid(); END IF;
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();

  IF auth.uid() IS NULL OR v_role IN ('super_admin','admin','supervisor','staff') THEN
    NEW.status       := 'approved';
    NEW.approved_by  := auth.uid();
    NEW.approved_at  := now();
    NEW.published_at := now();
  ELSE
    NEW.status       := 'pending';
    NEW.approved_by  := NULL;
    NEW.approved_at  := NULL;
    NEW.published_at := NULL;
  END IF;
  NEW.reject_reason := '';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS works_set_status ON public.works;
CREATE TRIGGER works_set_status
  BEFORE INSERT ON public.works
  FOR EACH ROW EXECUTE FUNCTION public.works_before_insert();

-- กันเจ้าของแก้สถานะตัวเองผ่าน UPDATE (ต้องใช้ RPC review_work เท่านั้น)
CREATE OR REPLACE FUNCTION public.works_before_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_role text;
BEGIN
  -- ต้องเป็น SECURITY INVOKER เพื่อให้ current_user สะท้อนผู้เรียกจริง:
  --   • client ยิงผ่าน PostgREST → current_user = 'authenticated'/'anon' → บังคับ guard
  --   • review_work (SECURITY DEFINER, เจ้าของ postgres) → current_user = 'postgres' → ข้าม
  -- เคยลองใช้ set_config('app.reviewing') แล้วไม่ได้ผล เพราะ SECURITY DEFINER
  -- ที่มี SET clause สร้าง GUC scope แยก ค่าจึงไม่ทะลุมาถึง trigger
  IF current_user NOT IN ('authenticated','anon') THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role NOT IN ('super_admin','admin') THEN
    NEW.status       := OLD.status;
    NEW.approved_by  := OLD.approved_by;
    NEW.approved_at  := OLD.approved_at;
    NEW.reject_reason:= OLD.reject_reason;
    NEW.owner_id     := OLD.owner_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS works_guard_update ON public.works;
CREATE TRIGGER works_guard_update
  BEFORE UPDATE ON public.works
  FOR EACH ROW EXECUTE FUNCTION public.works_before_update();

-- ── 3. RLS — แยกตามคำสั่ง ตาม pattern ของจดหมายข่าว (0057) ────
-- เดิม "works admin manage" เป็น FOR ALL ที่ให้ supervisor แก้/ลบของคนอื่นได้
-- ไม่เหมาะกับงานที่ให้เครดิตเจ้าของ → ศน. อนุมัติได้ แต่ไม่แก้เนื้อหาคนอื่น
DROP POLICY IF EXISTS "works public read approved" ON public.works;
DROP POLICY IF EXISTS "works owner insert"         ON public.works;
DROP POLICY IF EXISTS "works admin manage"         ON public.works;
DROP POLICY IF EXISTS "works: read"   ON public.works;
DROP POLICY IF EXISTS "works: insert" ON public.works;
DROP POLICY IF EXISTS "works: update" ON public.works;
DROP POLICY IF EXISTS "works: delete" ON public.works;

CREATE POLICY "works: read"
  ON public.works FOR SELECT
  USING (
    status = 'approved'
    OR owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );

CREATE POLICY "works: insert"
  ON public.works FOR INSERT
  WITH CHECK (
    owner_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_approved = true)
  );

CREATE POLICY "works: update"
  ON public.works FOR UPDATE
  USING (
    owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  )
  WITH CHECK (
    owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

CREATE POLICY "works: delete"
  ON public.works FOR DELETE
  USING (
    owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

-- ── 4. อนุมัติ/ปฏิเสธ — แยกเป็น RPC ────────────────────────────
-- ทำเป็น RPC แทนการเปิด UPDATE policy ให้ ศน. เพื่อให้อนุมัติได้
-- โดยไม่ได้สิทธิ์แก้ "เนื้อหา" ของคนอื่นไปด้วย
CREATE OR REPLACE FUNCTION public.review_work(p_id uuid, p_status text, p_reason text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_role text;
BEGIN
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'สถานะไม่ถูกต้อง';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role IS NULL OR v_role NOT IN ('super_admin','admin','supervisor') THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์อนุมัติผลงาน';
  END IF;

  UPDATE public.works SET
    status        = p_status,
    reject_reason = CASE WHEN p_status = 'rejected' THEN COALESCE(p_reason,'') ELSE '' END,
    approved_by   = CASE WHEN p_status = 'approved' THEN auth.uid() ELSE NULL END,
    approved_at   = CASE WHEN p_status = 'approved' THEN now() ELSE NULL END,
    published_at  = CASE WHEN p_status = 'approved' THEN COALESCE(published_at, now()) ELSE NULL END
  WHERE id = p_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'ไม่พบผลงาน'; END IF;
  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$$;
GRANT EXECUTE ON FUNCTION public.review_work(uuid, text, text) TO authenticated;

-- ── 5. สถิติ ดู/ถูกใจ (มิเรอร์จาก media) ──────────────────────
CREATE TABLE IF NOT EXISTS public.work_views (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_id    uuid NOT NULL REFERENCES public.works(id) ON DELETE CASCADE,
  user_id    uuid REFERENCES public.profiles(id),
  session_id text,
  viewed_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(work_id, session_id)
);

CREATE TABLE IF NOT EXISTS public.work_likes (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  work_id    uuid NOT NULL REFERENCES public.works(id) ON DELETE CASCADE,
  user_id    uuid REFERENCES public.profiles(id),
  ip_hash    text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(work_id, user_id),
  CONSTRAINT work_likes_anon UNIQUE NULLS NOT DISTINCT (work_id, ip_hash)
);

ALTER TABLE public.work_views ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_likes ENABLE ROW LEVEL SECURITY;

-- อ่าน/เพิ่มได้ แต่ห้ามลบ/แก้ (media เดิมเปิด FOR ALL ให้ anon ลบแถวได้ — ไม่ทำซ้ำ)
DROP POLICY IF EXISTS "work_views: read"   ON public.work_views;
DROP POLICY IF EXISTS "work_views: insert" ON public.work_views;
DROP POLICY IF EXISTS "work_likes: read"   ON public.work_likes;
DROP POLICY IF EXISTS "work_likes: insert" ON public.work_likes;
DROP POLICY IF EXISTS "work_likes: delete" ON public.work_likes;

CREATE POLICY "work_views: read"   ON public.work_views FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "work_views: insert" ON public.work_views FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "work_likes: read"   ON public.work_likes FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "work_likes: insert" ON public.work_likes FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "work_likes: delete" ON public.work_likes FOR DELETE TO anon, authenticated
  USING (user_id = auth.uid() OR user_id IS NULL);

CREATE OR REPLACE FUNCTION public.record_work_view(p_work_id uuid, p_session_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows int;
BEGIN
  INSERT INTO public.work_views (work_id, user_id, session_id)
  VALUES (p_work_id, auth.uid(), p_session_id)
  ON CONFLICT (work_id, session_id) DO NOTHING;

  -- ใช้ ROW_COUNT ไม่ใช่ FOUND — FOUND เป็น true เสมอแม้ ON CONFLICT DO NOTHING
  -- (บั๊กเดิมของ record_media_view ที่ทำให้ยอดชมนับซ้ำ แก้ใน migration ถัดไป)
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    UPDATE public.works SET view_count = view_count + 1 WHERE id = p_work_id;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_work_view(uuid, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.toggle_work_like(p_work_id uuid, p_ip_hash text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_liked   boolean;
  v_count   int;
BEGIN
  IF v_user_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.work_likes WHERE work_id = p_work_id AND user_id = v_user_id) THEN
      DELETE FROM public.work_likes WHERE work_id = p_work_id AND user_id = v_user_id;
      v_liked := false;
    ELSE
      INSERT INTO public.work_likes (work_id, user_id) VALUES (p_work_id, v_user_id);
      v_liked := true;
    END IF;
  ELSE
    IF EXISTS (SELECT 1 FROM public.work_likes WHERE work_id = p_work_id AND ip_hash = p_ip_hash) THEN
      DELETE FROM public.work_likes WHERE work_id = p_work_id AND ip_hash = p_ip_hash;
      v_liked := false;
    ELSE
      INSERT INTO public.work_likes (work_id, ip_hash) VALUES (p_work_id, p_ip_hash);
      v_liked := true;
    END IF;
  END IF;

  SELECT count(*) INTO v_count FROM public.work_likes WHERE work_id = p_work_id;
  UPDATE public.works SET like_count = v_count WHERE id = p_work_id;
  RETURN jsonb_build_object('liked', v_liked, 'like_count', v_count);
END;
$$;
GRANT EXECUTE ON FUNCTION public.toggle_work_like(uuid, text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.increment_work_download(p_work_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.works SET download_count = download_count + 1 WHERE id = p_work_id;
$$;
GRANT EXECUTE ON FUNCTION public.increment_work_download(uuid) TO anon, authenticated;

-- ── 6. RPC สาธารณะ (หน้า /works ใช้ anon key) ─────────────────
-- RLS ข้างบนให้ anon อ่าน status='approved' ได้อยู่แล้ว จึง query ตรงได้
-- แต่ต้องต่อชื่อเจ้าของมาด้วยเพื่อแสดงเครดิต — ทำเป็น view ให้ join ครั้งเดียว
CREATE OR REPLACE VIEW public.works_public AS
  SELECT w.id, w.work_type, w.owner_type, w.title, w.description, w.subject,
         w.subject_group, w.grade_level, w.grade_levels, w.academic_year,
         w.file_url, w.cover_url, w.tags, w.content_blocks,
         w.view_count, w.like_count, w.download_count, w.is_featured,
         w.published_at, w.created_at, w.school_name,
         COALESCE(NULLIF(TRIM(CONCAT(p.title, p.first_name,
           CASE WHEN p.last_name > '' THEN ' ' || p.last_name ELSE '' END)), ''), p.full_name) AS owner_name,
         p.position AS owner_position,
         p.avatar_url AS owner_avatar
  FROM public.works w
  LEFT JOIN public.profiles p ON p.id = w.owner_id
  WHERE w.status = 'approved';

GRANT SELECT ON public.works_public TO anon, authenticated;
