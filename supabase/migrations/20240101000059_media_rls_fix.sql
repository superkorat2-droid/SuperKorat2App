-- ปิดช่องโหว่ RLS ของคลังสื่อ + แก้บั๊กยอดชมนับซ้ำ
--
-- ปัญหาเดิม (20240101000029_media_library.sql:88-96):
--   CREATE POLICY "media: write" ON media FOR ALL USING (...)   ← ไม่มี WITH CHECK
-- FOR ALL ที่มีแต่ USING จะ "ไม่คุม INSERT เลย" เพราะ INSERT ตรวจจาก WITH CHECK
-- เท่านั้น ผลคือผู้ใช้ที่ล็อกอินคนไหนก็ insert สื่อโดยตั้ง created_by เป็นคนอื่น
-- และตั้ง is_published/is_approved = true เองได้ → ระบบอนุมัติไม่มีผลจริง
--
-- แก้ตาม pattern เดียวกับจดหมายข่าว (20240101000057)

-- ── 1. สถานะอนุมัติตามบทบาท — บังคับที่ DB ────────────────────
-- เดิม is_approved default true และ SchoolMediaEditorView hardcode true
-- ทำให้การ์ด "รออนุมัติ" ในหน้า admin เป็น 0 ตลอด
CREATE OR REPLACE FUNCTION public.media_before_insert()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_role text;
BEGIN
  NEW.created_by := auth.uid();        -- กันสวมชื่อคนอื่น
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();

  -- บุคลากรเขตเผยแพร่ได้ทันที · ครู/โรงเรียนรออนุมัติ (เกณฑ์เดียวกับ works)
  IF v_role IN ('super_admin','admin','supervisor','staff') THEN
    NEW.is_approved := true;
  ELSE
    NEW.is_approved := false;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS media_set_approval ON public.media;
CREATE TRIGGER media_set_approval
  BEFORE INSERT ON public.media
  FOR EACH ROW EXECUTE FUNCTION public.media_before_insert();

-- กันเจ้าของอนุมัติสื่อตัวเองผ่าน UPDATE
CREATE OR REPLACE FUNCTION public.media_before_update()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_role text;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role NOT IN ('super_admin','admin') THEN
    NEW.is_approved := OLD.is_approved;
    NEW.created_by  := OLD.created_by;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS media_guard_update ON public.media;
CREATE TRIGGER media_guard_update
  BEFORE UPDATE ON public.media
  FOR EACH ROW EXECUTE FUNCTION public.media_before_update();

-- ── 2. แยก policy ตามคำสั่ง ───────────────────────────────────
DROP POLICY IF EXISTS "media: write" ON public.media;

CREATE POLICY "media: insert"
  ON public.media FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND is_approved = true)
  );

-- โรงเรียนแก้สื่อของโรงเรียนตัวเองได้ด้วย (เดิมทำไม่ได้ถ้า ศน. เป็นคนสร้างให้)
CREATE POLICY "media: update"
  ON public.media FOR UPDATE
  USING (
    created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.school_id = media.school_id)
  )
  WITH CHECK (
    created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.school_id = media.school_id)
  );

CREATE POLICY "media: delete"
  ON public.media FOR DELETE
  USING (
    created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.school_id = media.school_id)
  );

-- ── 3. ตารางสถิติ — เดิมเปิด FOR ALL ให้ anon (ลบแถวคนอื่นได้) ──
DROP POLICY IF EXISTS "media_likes: all" ON public.media_likes;
DROP POLICY IF EXISTS "media_views: all" ON public.media_views;
DROP POLICY IF EXISTS "media_likes: anyone" ON public.media_likes;
DROP POLICY IF EXISTS "media_views: anyone" ON public.media_views;

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT policyname, tablename FROM pg_policies
           WHERE tablename IN ('media_likes','media_views') LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
  END LOOP;
END $$;

CREATE POLICY "media_views: read"   ON public.media_views FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "media_views: insert" ON public.media_views FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "media_likes: read"   ON public.media_likes FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "media_likes: insert" ON public.media_likes FOR INSERT TO anon, authenticated WITH CHECK (true);
CREATE POLICY "media_likes: delete" ON public.media_likes FOR DELETE TO anon, authenticated
  USING (user_id = auth.uid() OR user_id IS NULL);

-- ── 4. แก้บั๊กยอดชมนับซ้ำ ─────────────────────────────────────
-- FOUND เป็น true เสมอหลัง INSERT แม้ ON CONFLICT DO NOTHING จะไม่ได้เพิ่มแถว
-- ต้องเช็คจำนวนแถวจริงด้วย GET DIAGNOSTICS แทน
CREATE OR REPLACE FUNCTION public.record_media_view(p_media_id uuid, p_session_id text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows int;
BEGIN
  INSERT INTO public.media_views (media_id, user_id, session_id)
  VALUES (p_media_id, auth.uid(), p_session_id)
  ON CONFLICT (media_id, session_id) DO NOTHING;

  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows > 0 THEN
    UPDATE public.media SET view_count = view_count + 1 WHERE id = p_media_id;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_media_view(uuid, text) TO anon, authenticated;
