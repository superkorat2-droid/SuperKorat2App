-- บันทึกการนิเทศติดตาม (nithet_visits) — ผลการออกนิเทศจริงของศึกษานิเทศก์
--
-- ทำไมต้องมีตารางใหม่: ระบบเดิมไม่มีที่เก็บ "ผล" การนิเทศเลย
--   • nithet_events = แผนล่วงหน้า (ไปไหน วันไหน ใครไป) แล้วติ๊ก status='done'
--   • /dashboard/nithet-report ที่ชื่อ "รายงานผลการนิเทศ" อ่านจาก nithet_events ตรง ๆ
--     ไม่มีช่อง สภาพที่พบ / ข้อเสนอแนะ / รูป เลยแม้แต่ช่องเดียว
--   • supervision_* คือแบบสอบถามที่ ศน. สร้างให้ "โรงเรียนกรอก" คนละเรื่องกัน
--
-- 1 แถว = ไปนิเทศ 1 ครั้ง · ผูกกับแผนใน nithet_events ได้ (event_id) แต่ไม่บังคับ
-- เพราะต้องบันทึกย้อนหลังงานที่ไม่ได้ลงแผนไว้ได้ด้วย

-- ── 1. ตาราง ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.nithet_visits (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- draft = "บันทึกด่วน" หน้างาน (กรอกแค่ที่ไหน/วันไหน/รูป) · final = กรอกครบแล้ว
  status      text NOT NULL DEFAULT 'draft',
  event_id    uuid REFERENCES public.nithet_events(id) ON DELETE SET NULL,

  -- school_id เป็น NULL ได้ เพราะบางครั้งไม่ได้ไปโรงเรียน (เป็นวิทยากร/ประชุมนอกเขต)
  -- แล้วให้พิมพ์ place_name แทน · CHECK ท้ายตารางบังคับว่าต้องมีอย่างน้อยหนึ่งอย่าง
  school_id   uuid REFERENCES public.schools(id) ON DELETE SET NULL,
  place_name  text NOT NULL DEFAULT '',

  visit_date  date NOT NULL,
  visit_type  text NOT NULL DEFAULT 'school_visit',
  title       text NOT NULL DEFAULT '',
  topics      text[] NOT NULL DEFAULT '{}',
  -- เก็บเป็น "key" ให้ตรงกับ nithet_events.responsible_group ไม่ใช่ label
  -- (profiles.department เก็บ label ต้องแปลงด้วย keyFromLabel() ก่อน — บทเรียน migration 0073)
  work_group  text NOT NULL DEFAULT '',
  academic_year int,                      -- พ.ศ. อยู่แล้ว ห้าม +543 ซ้ำตอนแสดง
  term        smallint,

  -- เนื้อหาบันทึก แยกช่องเพื่อให้พิมพ์รายงานราชการและนับสถิติได้
  summary     text NOT NULL DEFAULT '',   -- สภาพที่พบ
  strengths   text NOT NULL DEFAULT '',   -- จุดเด่น
  issues      text NOT NULL DEFAULT '',   -- จุดที่ควรพัฒนา   (ไม่เผยแพร่สาธารณะ)
  suggestions text NOT NULL DEFAULT '',   -- ข้อเสนอแนะ       (ไม่เผยแพร่สาธารณะ)

  created_by        uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  co_supervisor_ids uuid[] NOT NULL DEFAULT '{}',
  receiver_name     text NOT NULL DEFAULT '',
  receiver_position text NOT NULL DEFAULT '',
  receiver_count    int,

  -- photos[0] = ภาพปกอัตโนมัติ ไม่ต้องอัปปกแยก
  -- เก็บ w/h ไว้ด้วยเพื่อกันหน้ากระตุกตอนโหลด และใช้ตัดสินแนวตั้ง/แนวนอนตอนจัดหน้ารายงาน
  photos jsonb NOT NULL DEFAULT '[]'::jsonb,   -- [{url, caption, w, h}]
  links  jsonb NOT NULL DEFAULT '[]'::jsonb,   -- [{url, label, kind}] kind: drive|youtube|other

  followup_required boolean NOT NULL DEFAULT false,
  followup_due      date,
  followup_status   text NOT NULL DEFAULT 'none',
  followup_note     text NOT NULL DEFAULT '',
  followup_of       uuid REFERENCES public.nithet_visits(id) ON DELETE SET NULL,

  is_public  boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT nithet_visits_status_chk   CHECK (status IN ('draft','final')),
  CONSTRAINT nithet_visits_type_chk     CHECK (visit_type IN ('school_visit','follow_up','meeting','speaker','other')),
  CONSTRAINT nithet_visits_term_chk     CHECK (term IS NULL OR term IN (1,2)),
  CONSTRAINT nithet_visits_year_chk     CHECK (academic_year IS NULL OR academic_year BETWEEN 2500 AND 2700),
  CONSTRAINT nithet_visits_count_chk    CHECK (receiver_count IS NULL OR receiver_count >= 0),
  CONSTRAINT nithet_visits_followup_chk CHECK (followup_status IN ('none','open','done','cancelled')),
  -- ต้องรู้ว่าไปที่ไหน อย่างน้อยอย่างใดอย่างหนึ่ง
  CONSTRAINT nithet_visits_place_chk    CHECK (school_id IS NOT NULL OR btrim(place_name) <> '')
);

COMMENT ON COLUMN public.nithet_visits.place_name IS
  'สถานที่/หน่วยงาน ใช้เมื่อไม่ได้ไปโรงเรียน (เป็นวิทยากร/ประชุมนอกเขต) — school_id จะเป็น NULL';
COMMENT ON COLUMN public.nithet_visits.photos IS
  '[{url, caption, w, h}] · photos[0] คือภาพปก · ไฟล์จริงอยู่บน PHP host ของเขต ไม่ใช่ Supabase Storage';
COMMENT ON COLUMN public.nithet_visits.work_group IS
  'key ของกลุ่มงาน (ตรงกับ nithet_events.responsible_group) ไม่ใช่ label — ดูบทเรียน migration 0073';

CREATE INDEX IF NOT EXISTS idx_nithet_visits_school   ON public.nithet_visits(school_id, visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_nithet_visits_owner    ON public.nithet_visits(created_by);
CREATE INDEX IF NOT EXISTS idx_nithet_visits_date     ON public.nithet_visits(visit_date DESC);
CREATE INDEX IF NOT EXISTS idx_nithet_visits_status   ON public.nithet_visits(status);
CREATE INDEX IF NOT EXISTS idx_nithet_visits_event    ON public.nithet_visits(event_id);
CREATE INDEX IF NOT EXISTS idx_nithet_visits_topics   ON public.nithet_visits USING GIN (topics);
CREATE INDEX IF NOT EXISTS idx_nithet_visits_followup ON public.nithet_visits(followup_due)
  WHERE followup_status = 'open';

ALTER TABLE public.nithet_visits ENABLE ROW LEVEL SECURITY;

-- ── 2. ใครเป็นบุคลากรเขต ────────────────────────────────────
-- ใช้ซ้ำหลายที่ใน RLS · SECURITY DEFINER เพื่ออ่าน profiles ได้โดยไม่ติด RLS ของตัวเอง
CREATE OR REPLACE FUNCTION public.is_area_staff()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('super_admin','admin','supervisor','staff')
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_area_staff() TO authenticated;

CREATE OR REPLACE FUNCTION public.is_area_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin')
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_area_admin() TO authenticated;

-- ── 3. trigger ──────────────────────────────────────────────
-- SECURITY INVOKER + เช็ค current_user (บทเรียนจาก 0058: SECURITY DEFINER ที่มี SET
-- clause สร้าง GUC scope แยก ทำให้ set_config ไม่ทะลุถึง trigger)
CREATE OR REPLACE FUNCTION public.nithet_visits_before_insert()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;

  -- เจ้าของบันทึกคือคนที่ล็อกอินอยู่เสมอ สวมชื่อคนอื่นไม่ได้
  IF auth.uid() IS NOT NULL THEN NEW.created_by := auth.uid(); END IF;

  -- ร่างห้ามหลุดออกหน้าเว็บสาธารณะ
  IF NEW.status = 'draft' THEN NEW.is_public := false; END IF;

  IF NEW.followup_required AND NEW.followup_status = 'none' THEN
    NEW.followup_status := 'open';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_nithet_visits_before_insert ON public.nithet_visits;
CREATE TRIGGER trg_nithet_visits_before_insert
  BEFORE INSERT ON public.nithet_visits
  FOR EACH ROW EXECUTE FUNCTION public.nithet_visits_before_insert();

CREATE OR REPLACE FUNCTION public.nithet_visits_before_update()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;

  -- โอนเจ้าของบันทึกไม่ได้
  NEW.created_by := OLD.created_by;

  IF NEW.status = 'draft' THEN NEW.is_public := false; END IF;

  IF NEW.followup_required AND NEW.followup_status = 'none' THEN
    NEW.followup_status := 'open';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_nithet_visits_before_update ON public.nithet_visits;
CREATE TRIGGER trg_nithet_visits_before_update
  BEFORE UPDATE ON public.nithet_visits
  FOR EACH ROW EXECUTE FUNCTION public.nithet_visits_before_update();

-- ── 4. RLS ──────────────────────────────────────────────────
-- แยกรายคำสั่ง ห้ามรวบเป็น FOR ALL เพราะไม่มี WITH CHECK = ไม่คุม INSERT
-- (ช่องโหว่เดิมของคลังสื่อที่ 0059 ต้องตามแก้)
DROP POLICY IF EXISTS "nithet_visits: read"   ON public.nithet_visits;
DROP POLICY IF EXISTS "nithet_visits: insert" ON public.nithet_visits;
DROP POLICY IF EXISTS "nithet_visits: update" ON public.nithet_visits;
DROP POLICY IF EXISTS "nithet_visits: delete" ON public.nithet_visits;

-- final: บุคลากรเขตเห็นหมด · โรงเรียนเห็นของโรงตัวเอง
-- draft: เห็นเฉพาะเจ้าของกับผู้ดูแล (งานที่ยังเขียนไม่เสร็จไม่ควรให้เพื่อนร่วมงานเห็น)
CREATE POLICY "nithet_visits: read"
  ON public.nithet_visits FOR SELECT TO authenticated
  USING (
    created_by = auth.uid()
    OR public.is_area_admin()
    OR (
      status = 'final'
      AND (
        public.is_area_staff()
        OR school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())
      )
    )
  );

CREATE POLICY "nithet_visits: insert"
  ON public.nithet_visits FOR INSERT TO authenticated
  WITH CHECK (created_by = auth.uid() AND public.is_area_staff());

CREATE POLICY "nithet_visits: update"
  ON public.nithet_visits FOR UPDATE TO authenticated
  USING      (created_by = auth.uid() OR public.is_area_admin())
  WITH CHECK (created_by = auth.uid() OR public.is_area_admin());

CREATE POLICY "nithet_visits: delete"
  ON public.nithet_visits FOR DELETE TO authenticated
  USING (created_by = auth.uid() OR public.is_area_admin());

-- ── 5. view สาธารณะ ─────────────────────────────────────────
-- view ไม่ใช่ security_invoker จึงรันด้วยสิทธิ์เจ้าของและข้าม RLS
-- **ตัวมันเองจึงต้องกรอง is_public + status เอง** และเปิดเฉพาะคอลัมน์ที่เผยแพร่ได้
--
-- issues / suggestions / receiver_* / followup_* ไม่เปิดเด็ดขาด — เป็นข้อมูลที่อ่อนไหว
-- ต่อโรงเรียน ถ้าเผลอกดเผยแพร่ก็ยังไม่หลุด เพราะกันไว้ตั้งแต่ระดับฐานข้อมูล
CREATE OR REPLACE VIEW public.nithet_visits_public AS
  SELECT v.id, v.visit_date, v.visit_type, v.title, v.topics,
         v.summary, v.strengths, v.photos, v.links,
         v.academic_year, v.term, v.created_at,
         v.place_name,
         s.name         AS school_name,
         s.district     AS school_district,
         s.school_group AS school_group,
         COALESCE(
           NULLIF(btrim(p.full_name), ''),
           NULLIF(btrim(concat_ws(' ', p.title, p.first_name, p.last_name)), '')
         ) AS supervisor_name,
         p.position AS supervisor_position
  FROM public.nithet_visits v
  LEFT JOIN public.schools  s ON s.id = v.school_id
  LEFT JOIN public.profiles p ON p.id = v.created_by
  WHERE v.is_public = true AND v.status = 'final';

GRANT SELECT ON public.nithet_visits_public TO anon, authenticated;

-- ── 6. คำแนะนำประเด็นการนิเทศ ───────────────────────────────
-- ระบบจำคำที่เคยใช้เอง ไม่ต้องมีหน้าตั้งค่าให้แอดมินดูแล
CREATE OR REPLACE VIEW public.nithet_topic_suggestions AS
  SELECT topic, count(*) AS uses
  FROM public.nithet_visits v, unnest(v.topics) AS topic
  WHERE btrim(topic) <> ''
  GROUP BY topic
  ORDER BY uses DESC, topic;

REVOKE ALL ON public.nithet_topic_suggestions FROM anon;
GRANT SELECT ON public.nithet_topic_suggestions TO authenticated;

NOTIFY pgrst, 'reload schema';
