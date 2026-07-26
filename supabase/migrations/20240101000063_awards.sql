-- ═══════════════════════════════════════════════════════════════════════
-- awards — ระบบผลงานและรางวัล (แยกจาก works)
--
-- ทำไมไม่รวมกับ works: ฟิลด์แทบไม่ซ้ำกันเลย (ชื่อรางวัล/ระดับ/ชั่วโมงอบรม/
-- สมาชิกกลุ่ม/ไอคอน) และคนละวัตถุประสงค์ — works = เผยแพร่ให้คนเอาไปใช้ต่อ
-- awards = เก็บเกียรติประวัติเพื่อสรุปเป็นสถิตินำเสนอ
-- รวมกันจะได้คอลัมน์ว่างเพียบและ UI เต็มไปด้วย v-if
--
-- กติกาสิทธิ์เหมือน works: คนในเขตกรอกแล้วขึ้นเลย · คนนอกรออนุมัติ
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.awards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- ── เจ้าของรางวัล ──
  -- owner_label เก็บ "ชื่อที่จะแสดง" เสมอ ไม่ว่าจะเลือกจากสมาชิกที่มีอยู่หรือพิมพ์เอง
  -- school_id / profile_id จะถูกเซ็ตก็ต่อเมื่อเลือกจากรายการที่มีในระบบ
  -- (คนนอกเขต/หน่วยงานอื่นพิมพ์ชื่อเองได้ โดย 2 ฟิลด์นี้เป็น NULL)
  owner_kind  text NOT NULL DEFAULT 'school',
  owner_label text NOT NULL DEFAULT '',
  school_id   uuid REFERENCES public.schools(id)  ON DELETE SET NULL,
  profile_id  uuid REFERENCES public.profiles(id) ON DELETE SET NULL,

  -- ── ตัวรางวัล ──
  title           text NOT NULL,
  award_rank      text NOT NULL DEFAULT 'certificate',
  award_rank_other text NOT NULL DEFAULT '',   -- ใช้เมื่อ award_rank = 'other'
  level           text NOT NULL DEFAULT 'area',
  issuer          text NOT NULL DEFAULT '',    -- หน่วยงานที่มอบรางวัล
  awarded_date    date,
  academic_year   text NOT NULL DEFAULT '',

  -- ── กรณีเป็นการอบรม/พัฒนาตนเอง ──
  is_training    boolean NOT NULL DEFAULT false,
  training_hours numeric(6,1) NOT NULL DEFAULT 0,

  -- ── ผลงานกลุ่ม ── [{name, org, profile_id}]
  is_group boolean NOT NULL DEFAULT false,
  members  jsonb   NOT NULL DEFAULT '[]'::jsonb,

  -- ── การแสดงผล ──
  icon     text NOT NULL DEFAULT 'trophy',
  link_url text NOT NULL DEFAULT '',           -- ลิงก์ผลงาน/เกียรติบัตร (Drive สาธารณะ)
  note     text NOT NULL DEFAULT '',

  -- ── การตรวจสอบ ──
  status        text NOT NULL DEFAULT 'pending',
  reject_reason text NOT NULL DEFAULT '',
  approved_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  approved_at   timestamptz,
  created_by    uuid REFERENCES public.profiles(id) ON DELETE SET NULL,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT awards_status_chk CHECK (status IN ('pending','approved','rejected')),
  CONSTRAINT awards_level_chk  CHECK (level IN ('area','province','region','national','international')),
  CONSTRAINT awards_owner_chk  CHECK (owner_kind IN ('area','school','teacher','supervisor','staff','other'))
);

CREATE INDEX IF NOT EXISTS idx_awards_status  ON public.awards(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_awards_school  ON public.awards(school_id);
CREATE INDEX IF NOT EXISTS idx_awards_year    ON public.awards(academic_year);
CREATE INDEX IF NOT EXISTS idx_awards_level   ON public.awards(level);

-- "ผู้ได้รับมอบหมาย" ที่ไม่ใช่ ศน. แต่ถูกมอบให้กรอกแทน
-- ตาม pattern can_publish_supervision / can_manage_documents ที่มีอยู่แล้ว
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_manage_awards boolean NOT NULL DEFAULT false;

ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS show_public_awards boolean DEFAULT true;

ALTER TABLE public.awards ENABLE ROW LEVEL SECURITY;

-- ── ใครกรอกแทนคนอื่นได้บ้าง ────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.can_manage_all_awards()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (p.role IN ('super_admin','admin','supervisor','staff')
           OR p.can_manage_awards = true)
  );
$$;
GRANT EXECUTE ON FUNCTION public.can_manage_all_awards() TO authenticated;

-- ── trigger: ไม่เชื่อ status ที่ client ส่งมา ──────────────────────────
-- SECURITY INVOKER + current_user (บทเรียนจาก 0058: SECURITY DEFINER ที่มี SET
-- clause สร้าง GUC scope แยก ทำให้ set_config ไม่ทะลุถึง trigger)
CREATE OR REPLACE FUNCTION public.awards_before_insert()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_role text; v_can boolean;
BEGIN
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;

  IF auth.uid() IS NOT NULL THEN NEW.created_by := auth.uid(); END IF;

  SELECT role, can_manage_awards INTO v_role, v_can
  FROM public.profiles WHERE id = auth.uid();

  IF auth.uid() IS NULL
     OR v_role IN ('super_admin','admin','supervisor','staff')
     OR COALESCE(v_can, false) THEN
    NEW.status      := 'approved';
    NEW.approved_by := auth.uid();
    NEW.approved_at := now();
  ELSE
    NEW.status      := 'pending';
    NEW.approved_by := NULL;
    NEW.approved_at := NULL;
  END IF;
  NEW.reject_reason := '';
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_awards_before_insert ON public.awards;
CREATE TRIGGER trg_awards_before_insert
  BEFORE INSERT ON public.awards
  FOR EACH ROW EXECUTE FUNCTION public.awards_before_insert();

-- กันคนแก้ status ของตัวเองให้เป็น approved ผ่าน UPDATE ปกติ
CREATE OR REPLACE FUNCTION public.awards_before_update()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  IF current_user NOT IN ('authenticated','anon') THEN RETURN NEW; END IF;
  -- การเปลี่ยนสถานะทำได้ทางเดียวคือผ่าน RPC review_award (SECURITY DEFINER)
  NEW.status        := OLD.status;
  NEW.approved_by   := OLD.approved_by;
  NEW.approved_at   := OLD.approved_at;
  NEW.reject_reason := OLD.reject_reason;
  NEW.created_by    := OLD.created_by;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_awards_before_update ON public.awards;
CREATE TRIGGER trg_awards_before_update
  BEFORE UPDATE ON public.awards
  FOR EACH ROW EXECUTE FUNCTION public.awards_before_update();

-- ── RLS ────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "awards: read"   ON public.awards;
DROP POLICY IF EXISTS "awards: insert" ON public.awards;
DROP POLICY IF EXISTS "awards: update" ON public.awards;
DROP POLICY IF EXISTS "awards: delete" ON public.awards;

-- เห็นได้: ที่อนุมัติแล้ว (ทุกคน) · ของตัวเอง · โรงเรียนของตัวเอง · ผู้มีสิทธิ์จัดการ
CREATE POLICY "awards: read" ON public.awards
  FOR SELECT TO anon, authenticated
  USING (
    status = 'approved'
    OR created_by = auth.uid()
    OR public.can_manage_all_awards()
    OR school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())
  );

-- ต้องเป็นบัญชีที่อนุมัติแล้วเท่านั้นถึงจะเพิ่มได้ (anon เพิ่มไม่ได้)
CREATE POLICY "awards: insert" ON public.awards
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.is_approved = true)
  );

-- แก้ได้: ของตัวเอง · โรงเรียนของตัวเอง · ผู้มีสิทธิ์จัดการ
CREATE POLICY "awards: update" ON public.awards
  FOR UPDATE TO authenticated
  USING (
    created_by = auth.uid()
    OR public.can_manage_all_awards()
    OR school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())
  )
  WITH CHECK (
    created_by = auth.uid()
    OR public.can_manage_all_awards()
    OR school_id IN (SELECT school_id FROM public.profiles WHERE id = auth.uid())
  );

CREATE POLICY "awards: delete" ON public.awards
  FOR DELETE TO authenticated
  USING (
    created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role IN ('super_admin','admin'))
  );

-- ── RPC อนุมัติ ────────────────────────────────────────────────────────
-- แยกจาก UPDATE policy เพื่อให้ ศน. อนุมัติได้โดยไม่ต้องเปิดสิทธิ์แก้เนื้อหาคนอื่น
CREATE OR REPLACE FUNCTION public.review_award(p_id uuid, p_status text, p_reason text DEFAULT '')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_role text;
BEGIN
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'สถานะไม่ถูกต้อง';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = auth.uid();
  IF v_role IS NULL OR v_role NOT IN ('super_admin','admin','supervisor') THEN
    RAISE EXCEPTION 'ไม่มีสิทธิ์อนุมัติรางวัล';
  END IF;

  UPDATE public.awards SET
    status        = p_status,
    reject_reason = CASE WHEN p_status = 'rejected' THEN COALESCE(p_reason,'') ELSE '' END,
    approved_by   = CASE WHEN p_status = 'approved' THEN auth.uid() ELSE NULL END,
    approved_at   = CASE WHEN p_status = 'approved' THEN now() ELSE NULL END
  WHERE id = p_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'ไม่พบรางวัล'; END IF;
  RETURN jsonb_build_object('ok', true, 'status', p_status);
END;
$$;
GRANT EXECUTE ON FUNCTION public.review_award(uuid, text, text) TO authenticated;

-- ── view สาธารณะ + ข้อมูลสำหรับรายงาน ─────────────────────────────────
-- join โรงเรียนมาให้ เพราะรายงานต้องกรองตาม "ศูนย์เครือข่าย" (schools.school_group)
-- และ "อำเภอ" (schools.district) ซึ่งมีอยู่ในระบบแล้ว ไม่ต้องเพิ่มฟิลด์
CREATE OR REPLACE VIEW public.awards_public AS
  SELECT a.id, a.owner_kind, a.owner_label, a.school_id, a.profile_id,
         a.title, a.award_rank, a.award_rank_other, a.level, a.issuer,
         a.awarded_date, a.academic_year,
         a.is_training, a.training_hours,
         a.is_group, a.members,
         a.icon, a.link_url, a.note,
         a.created_at,
         s.name         AS school_name,
         s.school_group AS school_group,   -- ศูนย์เครือข่าย
         s.district     AS school_district
  FROM public.awards a
  LEFT JOIN public.schools s ON s.id = a.school_id
  WHERE a.status = 'approved';

GRANT SELECT ON public.awards_public TO anon, authenticated;

-- ── เปิด realtime ให้แดชบอร์ดนำเสนอ ───────────────────────────────────
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.awards;
EXCEPTION
  WHEN duplicate_object THEN NULL;   -- เพิ่มไว้แล้ว
  WHEN undefined_object THEN NULL;   -- ไม่มี publication (local บาง setup)
END $$;

NOTIFY pgrst, 'reload schema';
