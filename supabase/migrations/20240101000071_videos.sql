-- วีดิทัศน์การศึกษา (videos) — คลังวิดีโอรวมจากโรงเรียน/ครู/ศน./สมาชิก
--
-- ทำไมไม่ต่อยอด media: media.media_type='video' คือ "สื่อการสอน" ที่มีหน้ารายละเอียด
-- + content_blocks + ดาวน์โหลด · ส่วนนี้คือ "คลิปดูจบในโมดัล" ที่ต้องผ่านคิวอนุมัติ
-- คนละ metadata คนละ lifecycle (เหตุผลเดียวกับที่ 0058 แยก works ออกจาก media)
--
-- รับได้ทั้ง YouTube และ Google Drive ในตารางเดียว โดยเก็บ source + video_id ที่สกัด
-- ไว้แล้วตอนบันทึก ฝั่งหน้าเว็บจะได้ไม่ต้อง regex ซ้ำทุกครั้งที่เรนเดอร์การ์ด

-- ── 1. ตาราง ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.videos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  title         text NOT NULL,
  description   text NOT NULL DEFAULT '',

  -- video_url = ลิงก์ดิบที่ผู้ใช้วางมา (เก็บไว้อ้างอิง/ให้กดออกไปดูที่ต้นทาง)
  -- video_id  = id 11 ตัวของ YouTube หรือ file id ของ Drive (ตัวที่ใช้เรนเดอร์จริง)
  source        text NOT NULL,
  video_url     text NOT NULL,
  video_id      text NOT NULL,
  -- ปกที่อัปทับเอง · NULL = ดึงอัตโนมัติจาก img.youtube.com หรือ drive thumbnail
  -- ⚠️ ห้ามใช้ iframe ทำภาพปก วัดแล้วหนักกว่า <img> 64 เท่า (useGoogleDrive.js:40-54)
  thumb_url     text,
  duration_text text NOT NULL DEFAULT '',   -- "12:34" กรอกเอง ไม่ได้ดึงจาก API

  category      text NOT NULL DEFAULT 'other',
  tags          text[] NOT NULL DEFAULT '{}',
  -- พ.ศ. เหมือน library_items.year — ห้าม +543 ซ้ำตอนแสดง
  academic_year int,

  owner_id      uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  owner_type    text NOT NULL DEFAULT 'member',
  school_id     uuid REFERENCES public.schools(id) ON DELETE SET NULL,

  status        text NOT NULL DEFAULT 'pending',
  reject_reason text NOT NULL DEFAULT '',
  approved_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at   timestamptz,
  published_at  timestamptz,

  view_count    int     NOT NULL DEFAULT 0,
  is_featured   boolean NOT NULL DEFAULT false,
  sort_order    int     NOT NULL DEFAULT 99,

  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT videos_source_chk   CHECK (source IN ('youtube','drive')),
  CONSTRAINT videos_status_chk   CHECK (status IN ('pending','approved','rejected')),
  CONSTRAINT videos_owner_chk    CHECK (owner_type IN ('area','school','teacher','supervisor','member')),
  CONSTRAINT videos_year_chk     CHECK (academic_year IS NULL OR academic_year BETWEEN 2500 AND 2700),
  CONSTRAINT videos_video_id_chk CHECK (btrim(video_id) <> ''),
  -- เพิ่มหมวดใหม่ทีหลังทำได้ 2 บรรทัด (แล้วต้องแก้ VIDEO_CATEGORIES ใน useVideos.js ให้ตรงกัน):
  --   ALTER TABLE public.videos DROP CONSTRAINT videos_category_chk;
  --   ALTER TABLE public.videos ADD  CONSTRAINT videos_category_chk CHECK (category IN (...));
  CONSTRAINT videos_category_chk CHECK (category IN
    ('learning','activity','training','supervision','announcement','best_practice','ceremony','other'))
);

COMMENT ON COLUMN public.videos.video_id IS
  'YouTube video id (11 ตัว) หรือ Google Drive file id — สกัดตอนบันทึก ไม่ regex ซ้ำตอนเรนเดอร์';
COMMENT ON COLUMN public.videos.academic_year IS
  'ปีการศึกษาเป็น พ.ศ. (เช่น 2569) ห้าม +543 ซ้ำ — ใช้ CURRENT_BE_YEAR จาก useLibraryOptions.js';
COMMENT ON COLUMN public.videos.owner_id IS
  'ผู้ส่ง = เจ้าของเครดิต · trigger เขียนทับด้วย auth.uid() เสมอ ห้ามเชื่อค่าจาก client';

CREATE INDEX IF NOT EXISTS videos_status_idx   ON public.videos(status, created_at DESC);
CREATE INDEX IF NOT EXISTS videos_owner_idx    ON public.videos(owner_id);
CREATE INDEX IF NOT EXISTS videos_school_idx   ON public.videos(school_id);
CREATE INDEX IF NOT EXISTS videos_category_idx ON public.videos(category);
CREATE INDEX IF NOT EXISTS videos_year_idx     ON public.videos(academic_year);
-- ดัชนีที่หน้าแรก/หน้ารวมใช้จริง: อนุมัติแล้ว → แนะนำก่อน → ลำดับ → ใหม่สุด
CREATE INDEX IF NOT EXISTS videos_feed_idx
  ON public.videos(status, is_featured DESC, sort_order, published_at DESC NULLS LAST);

-- สิทธิ์มอบหมาย (pattern เดียวกับ can_manage_awards ใน 0063)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_manage_videos boolean NOT NULL DEFAULT false;

ALTER TABLE public.videos ENABLE ROW LEVEL SECURITY;

-- ── 2. ใครจัดการวีดิทัศน์ของคนอื่นได้ ────────────────────────
-- เจตนาเดียวกับ works: ศน. "อนุมัติ" ได้ผ่าน RPC แต่ "แก้เนื้อหา" ของคนอื่นไม่ได้
-- จึงไม่ใส่ supervisor/staff ในนี้ (ใครเติมเข้าไปคือเปลี่ยนเจตนา)
CREATE OR REPLACE FUNCTION public.can_manage_all_videos()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (p.role IN ('super_admin','admin') OR p.can_manage_videos = true)
  );
$$;
GRANT EXECUTE ON FUNCTION public.can_manage_all_videos() TO authenticated;

-- ── 3. สถานะตามบทบาท — บังคับที่ DB ห้ามเชื่อค่าจาก client ────
-- บุคลากรเขต (ศน./เจ้าหน้าที่/admin) เผยแพร่ได้ทันที · ครู/โรงเรียน/สมาชิก รออนุมัติ
CREATE OR REPLACE FUNCTION public.videos_before_insert()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
DECLARE v_role text; v_school uuid;
BEGIN
  -- ไม่มี JWT (service role / seed script) → เคารพค่าที่ส่งมา ไม่งั้นติด NOT NULL
  IF auth.uid() IS NULL THEN RETURN NEW; END IF;

  NEW.owner_id := auth.uid();   -- กันสร้างแล้วสวมชื่อคนอื่น
  SELECT role, school_id INTO v_role, v_school FROM public.profiles WHERE id = auth.uid();

  -- owner_type คิดจาก role เสมอ ไม่รับจาก client (ไม่งั้นครูส่งมาว่าเป็น 'area' ได้)
  NEW.owner_type := CASE v_role
    WHEN 'school'      THEN 'school'
    WHEN 'teacher'     THEN 'teacher'
    WHEN 'supervisor'  THEN 'supervisor'
    WHEN 'staff'       THEN 'supervisor'
    WHEN 'admin'       THEN 'area'
    WHEN 'super_admin' THEN 'area'
    ELSE 'member'
  END;

  -- โรงเรียน/ครู ล็อกให้เป็นโรงเรียนตัวเองเสมอ กันสวมชื่อโรงเรียนอื่น
  IF v_role IN ('school','teacher') THEN
    NEW.school_id := v_school;
  END IF;

  IF v_role IN ('super_admin','admin','supervisor','staff') THEN
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

DROP TRIGGER IF EXISTS videos_set_status ON public.videos;
CREATE TRIGGER videos_set_status
  BEFORE INSERT ON public.videos
  FOR EACH ROW EXECUTE FUNCTION public.videos_before_insert();

-- กันแก้สถานะ/เจ้าของ/ยอดชม ผ่าน UPDATE ตรง — ต้องผ่าน RPC เท่านั้น
CREATE OR REPLACE FUNCTION public.videos_before_update()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN
  -- ต้องเป็น SECURITY INVOKER เพื่อให้ current_user สะท้อนผู้เรียกจริง:
  --   • client ยิงผ่าน PostgREST → current_user = 'authenticated'/'anon' → บังคับ guard
  --   • review_video / record_video_view (SECURITY DEFINER เจ้าของ postgres) → ข้าม
  -- set_config('app.xxx') ใช้ไม่ได้ เพราะ SECURITY DEFINER ที่มี SET clause
  -- สร้าง GUC scope แยก ค่าไม่ทะลุมาถึง trigger (บทเรียนจาก 0058)
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;

  -- freeze กับ client ทุกคนแม้แต่ admin ให้มีทางเปลี่ยนสถานะทางเดียว = review_video
  NEW.status        := OLD.status;
  NEW.approved_by   := OLD.approved_by;
  NEW.approved_at   := OLD.approved_at;
  NEW.published_at  := OLD.published_at;
  NEW.reject_reason := OLD.reject_reason;
  NEW.owner_id      := OLD.owner_id;
  NEW.view_count    := OLD.view_count;   -- นับผ่าน record_video_view เท่านั้น
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS videos_guard_update ON public.videos;
CREATE TRIGGER videos_guard_update
  BEFORE UPDATE ON public.videos
  FOR EACH ROW EXECUTE FUNCTION public.videos_before_update();

DROP TRIGGER IF EXISTS videos_updated_at ON public.videos;
CREATE TRIGGER videos_updated_at
  BEFORE UPDATE ON public.videos
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── 4. RLS — แยกตามคำสั่ง ────────────────────────────────────
-- ⚠️ ห้ามรวบเป็น FOR ALL ... USING(...) เดี่ยว ๆ เพราะไม่มี WITH CHECK = ไม่คุม INSERT เลย
-- (ช่องโหว่เดิมของคลังสื่อ ที่ 0059 ต้องตามแก้)
DROP POLICY IF EXISTS "videos: read"   ON public.videos;
DROP POLICY IF EXISTS "videos: insert" ON public.videos;
DROP POLICY IF EXISTS "videos: update" ON public.videos;
DROP POLICY IF EXISTS "videos: delete" ON public.videos;

-- เห็นได้: อนุมัติแล้ว(ทุกคน) · ของตัวเอง · ของโรงเรียนตัวเอง · บุคลากรเขต
CREATE POLICY "videos: read"
  ON public.videos FOR SELECT TO anon, authenticated
  USING (
    status = 'approved'
    OR owner_id = auth.uid()
    OR public.can_manage_all_videos()
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
    OR school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())
  );

-- เพิ่มได้เฉพาะบัญชีที่ผ่านการอนุมัติแล้ว และต้องเป็นชื่อตัวเอง
CREATE POLICY "videos: insert"
  ON public.videos FOR INSERT TO authenticated
  WITH CHECK (
    owner_id = auth.uid()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_approved = true)
  );

-- แก้ได้: ของตัวเอง · ของโรงเรียนตัวเอง · ผู้ดูแล — ต้องมีทั้ง USING และ WITH CHECK
CREATE POLICY "videos: update"
  ON public.videos FOR UPDATE TO authenticated
  USING (
    owner_id = auth.uid()
    OR public.can_manage_all_videos()
    OR school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    owner_id = auth.uid()
    OR public.can_manage_all_videos()
    OR school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())
  );

CREATE POLICY "videos: delete"
  ON public.videos FOR DELETE TO authenticated
  USING (
    owner_id = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles
               WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

-- ── 5. RPC อนุมัติ / ตีกลับ ──────────────────────────────────
CREATE OR REPLACE FUNCTION public.review_video(p_id uuid, p_status text, p_reason text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_role text;
BEGIN
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'สถานะไม่ถูกต้อง';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role IS NULL OR v_role NOT IN ('super_admin','admin','supervisor') THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์อนุมัติวีดิทัศน์';
  END IF;

  UPDATE public.videos SET
    status        = p_status,
    reject_reason = CASE WHEN p_status = 'rejected' THEN COALESCE(p_reason,'') ELSE '' END,
    approved_by   = CASE WHEN p_status = 'approved' THEN auth.uid() ELSE NULL END,
    approved_at   = CASE WHEN p_status = 'approved' THEN now() ELSE NULL END,
    published_at  = CASE WHEN p_status = 'approved' THEN COALESCE(published_at, now()) ELSE NULL END
  WHERE id = p_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'ไม่พบวีดิทัศน์'; END IF;
  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$$;
GRANT EXECUTE ON FUNCTION public.review_video(uuid, text, text) TO authenticated;

-- ── 6. ยอดชม ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.video_views (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  video_id   uuid NOT NULL REFERENCES public.videos(id) ON DELETE CASCADE,
  user_id    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  session_id text,
  viewed_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(video_id, session_id)
);
ALTER TABLE public.video_views ENABLE ROW LEVEL SECURITY;

-- อ่าน/เพิ่มได้ แต่ไม่มี policy ลบ/แก้ (คลังสื่อเดิมเปิด FOR ALL ให้ anon ลบแถวได้ — ไม่ทำซ้ำ)
DROP POLICY IF EXISTS "video_views: read"   ON public.video_views;
DROP POLICY IF EXISTS "video_views: insert" ON public.video_views;
CREATE POLICY "video_views: read"   ON public.video_views FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "video_views: insert" ON public.video_views FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.record_video_view(p_video_id uuid, p_session_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows int;
BEGIN
  INSERT INTO public.video_views (video_id, user_id, session_id)
  VALUES (p_video_id, auth.uid(), p_session_id)
  ON CONFLICT (video_id, session_id) DO NOTHING;

  -- ⚠️ ต้องใช้ ROW_COUNT ไม่ใช่ FOUND — FOUND เป็น true เสมอแม้ ON CONFLICT DO NOTHING
  -- (บั๊กเดิมของ record_media_view ที่ทำให้ยอดชมนับซ้ำทุกครั้ง แก้ไปแล้วใน 0059)
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    UPDATE public.videos SET view_count = view_count + 1 WHERE id = p_video_id;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_video_view(uuid, text) TO anon, authenticated;

-- ── 7. View สำหรับหน้าสาธารณะ ────────────────────────────────
-- view ไม่ใช่ SECURITY INVOKER จึงรันด้วยสิทธิ์เจ้าของและข้าม RLS
-- **ตัวมันเองจึงต้องกรอง status='approved' เอง** และเปิดเฉพาะคอลัมน์ที่เผยแพร่ได้
-- (แพทเทิร์นเดียวกับ library_public / works_public / awards_public)
CREATE OR REPLACE VIEW public.videos_public AS
SELECT
  v.id, v.title, v.description,
  v.source, v.video_url, v.video_id, v.thumb_url, v.duration_text,
  v.category, v.tags, v.academic_year,
  v.owner_id, v.owner_type, v.school_id,
  v.view_count, v.is_featured, v.sort_order,
  v.published_at, v.created_at, v.updated_at,
  COALESCE(
    NULLIF(btrim(p.full_name), ''),
    NULLIF(btrim(concat_ws(' ', p.title, p.first_name, p.last_name)), '')
  ) AS owner_name,
  p.position   AS owner_position,
  p.avatar_url AS owner_avatar,
  s.name       AS school_name
FROM public.videos v
LEFT JOIN public.profiles p ON p.id = v.owner_id
LEFT JOIN public.schools  s ON s.id = v.school_id
WHERE v.status = 'approved';

GRANT SELECT ON public.videos_public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
