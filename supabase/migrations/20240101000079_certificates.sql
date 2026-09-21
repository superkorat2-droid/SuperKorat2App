-- ═══════════════════════════════════════════════════════════════════════
-- คลังเกียรติบัตร — เขต/แอดมินวางลิงก์เกียรติบัตรที่ออกจาก Google Apps Script
-- (หรือไฟล์ Drive) แล้วขึ้นเป็นการ์ดภาพปกให้คนคลิกเปิดต่อ
--
-- โครงสร้างอิง library_items (migration 0068) เกือบทั้งหมด: ไม่มีคิวอนุมัติ
-- เขต/แอดมิน 4 บทบาทจัดการเองได้เลย, group_key ผูก area_config.personnel_groups
-- (เก็บ key ไม่ใช่ label กันชื่อกลุ่มเปลี่ยนแล้วข้อมูลขาด), responsible_id ผูก
-- บัญชีสมาชิกจริงเหมือน publisher_id ของ library_items
--
-- ต่างจาก library_items ตรงที่ภาพปกแยกอิสระจากลิงก์ปลายทาง (link_url อาจเป็น
-- หน้าเว็บ GAS ที่ครอบ thumbnail ไม่ได้) จึงมี cover_source/cover_url/cover_drive_id
-- เป็นชุดของตัวเอง และมี open_count นับจำนวนคลิกเปิด (library_items ไม่มี)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.certificates (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title          text NOT NULL,
  group_key      text,          -- key (ไม่ใช่ label) จาก area_config.personnel_groups
  responsible_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  cert_date      date,          -- วันที่ออกเกียรติบัตร ใช้จัดเรียง

  link_url       text NOT NULL DEFAULT '',   -- ลิงก์เกียรติบัตรจริง (GAS/Drive ฯลฯ) เปิดแท็บใหม่

  cover_source   text NOT NULL DEFAULT 'upload',
  cover_url      text,          -- ใช้เมื่อ cover_source = 'upload' (URL จาก PHP host หลังครอบ)
  cover_drive_id text,          -- ใช้เมื่อ cover_source = 'drive' (file id ที่ extract จากลิงก์ share)

  is_published   boolean NOT NULL DEFAULT true,
  open_count     int NOT NULL DEFAULT 0,

  created_by     uuid REFERENCES public.profiles(id),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT certificates_cover_source_chk CHECK (cover_source IN ('upload','drive'))
);

CREATE INDEX IF NOT EXISTS certificates_group_idx      ON public.certificates(group_key);
CREATE INDEX IF NOT EXISTS certificates_responsible_idx ON public.certificates(responsible_id);
CREATE INDEX IF NOT EXISTS certificates_created_by_idx  ON public.certificates(created_by);
CREATE INDEX IF NOT EXISTS certificates_published_idx   ON public.certificates(is_published);
CREATE INDEX IF NOT EXISTS certificates_date_idx        ON public.certificates(cert_date DESC);

COMMENT ON COLUMN public.certificates.created_by IS
  'คนที่กรอกเข้าระบบ — ใช้ตัดสินสิทธิ์แก้/ลบใน RLS ห้ามเขียนทับตอน UPDATE (จะเป็นการโอนเจ้าของ)';
COMMENT ON COLUMN public.certificates.responsible_id IS
  'ผู้รับผิดชอบที่ได้เครดิต — คนละเรื่องกับ created_by คนหนึ่งลงเกียรติบัตรให้อีกคนได้';
COMMENT ON COLUMN public.certificates.group_key IS
  'key จาก area_config.personnel_groups (ไม่ใช่ label) เพื่อให้เปลี่ยนชื่อกลุ่มแล้วข้อมูลไม่ขาด';

-- updated_at อัตโนมัติ
CREATE OR REPLACE FUNCTION public.certificates_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_certificates_updated_at ON public.certificates;
CREATE TRIGGER trg_certificates_updated_at
  BEFORE UPDATE ON public.certificates
  FOR EACH ROW EXECUTE FUNCTION public.certificates_set_updated_at();

ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;

-- ── อ่าน ────────────────────────────────────────────────────────────────
-- คนทั่วไปเห็นเฉพาะที่เผยแพร่แล้ว · คนในเขต 4 บทบาทเห็นทุกแถวรวมฉบับร่าง
CREATE POLICY "certificates: public read" ON public.certificates
FOR SELECT TO anon, authenticated
USING (
  is_published = true
  OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = ANY (ARRAY['super_admin','admin','supervisor','staff'])
  )
);

-- ── เพิ่ม ───────────────────────────────────────────────────────────────
-- created_by ต้องเป็นตัวเองเสมอ แม้แต่ admin (แม่แบบจาก documents 0066 / library 0068)
CREATE POLICY "certificates: insert" ON public.certificates
FOR INSERT
WITH CHECK (
  created_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = ANY (ARRAY['super_admin','admin','supervisor','staff'])
  )
);

-- ── แก้ไข ───────────────────────────────────────────────────────────────
CREATE POLICY "certificates: update" ON public.certificates
FOR UPDATE
USING (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
  OR (created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role = ANY (ARRAY['supervisor','staff'])))
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
  OR (created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role = ANY (ARRAY['supervisor','staff'])))
);

-- ── ลบ ──────────────────────────────────────────────────────────────────
CREATE POLICY "certificates: delete" ON public.certificates
FOR DELETE
USING (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
  OR (created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role = ANY (ARRAY['supervisor','staff'])))
);

-- ── นับยอดเปิดดู ───────────────────────────────────────────────────────
-- เพิ่มทีละ 1 ต่อคลิก ไม่มีตาราง dedup (ตามที่ตกลง เพื่อความง่าย) —
-- กันนับซ้ำแบบหยาบด้วย sessionStorage ฝั่ง client แทน (ดู CertificateCard.vue)
CREATE OR REPLACE FUNCTION public.increment_certificate_open(p_id uuid)
RETURNS void LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  UPDATE public.certificates SET open_count = open_count + 1 WHERE id = p_id;
$$;
GRANT EXECUTE ON FUNCTION public.increment_certificate_open(uuid) TO anon, authenticated;

-- ═══════════════════════════════════════════════════════════════════════
-- View สำหรับหน้าสาธารณะ — แบนชื่อผู้รับผิดชอบมาให้ตรงแพทเทิร์น library_public
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW public.certificates_public AS
SELECT
  c.id, c.title, c.group_key, c.responsible_id, c.cert_date, c.link_url,
  c.cover_source, c.cover_url, c.cover_drive_id, c.open_count,
  c.created_at, c.updated_at,
  COALESCE(
    NULLIF(btrim(p.full_name), ''),
    NULLIF(btrim(concat_ws(' ', p.title, p.first_name, p.last_name)), '')
  ) AS responsible_name,
  p.avatar_url AS responsible_avatar
FROM public.certificates c
LEFT JOIN public.profiles p ON p.id = c.responsible_id
WHERE c.is_published = true;

GRANT SELECT ON public.certificates_public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
