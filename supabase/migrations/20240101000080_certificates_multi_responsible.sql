-- ═══════════════════════════════════════════════════════════════════════
-- คลังเกียรติบัตร — รองรับผู้รับผิดชอบหลายคนต่อ 1 เกียรติบัตร
--
-- เดิม responsible_id เป็น FK เดี่ยว เลือกได้แค่คนเดียว แต่งานจริงบางชิ้นทำร่วมกัน
-- 2+ คน จึงเปลี่ยนเป็น responsible_ids uuid[] (ยังผูกกับบัญชีสมาชิกจริงเหมือนเดิม
-- ไม่ใช่ข้อความอิสระ) ข้อมูลเก่าที่มีอยู่ย้ายเข้า array 1 ตัวให้อัตโนมัติ
-- ═══════════════════════════════════════════════════════════════════════

-- view เดิมอ้างถึง responsible_id อยู่ ต้องดรอปก่อนถึงจะ DROP COLUMN ได้ (สร้างใหม่ท้ายไฟล์)
DROP VIEW IF EXISTS public.certificates_public;

ALTER TABLE public.certificates ADD COLUMN IF NOT EXISTS responsible_ids uuid[] NOT NULL DEFAULT '{}';

UPDATE public.certificates
SET responsible_ids = ARRAY[responsible_id]
WHERE responsible_id IS NOT NULL AND responsible_ids = '{}';

DROP INDEX IF EXISTS public.certificates_responsible_idx;
ALTER TABLE public.certificates DROP COLUMN IF EXISTS responsible_id;

CREATE INDEX IF NOT EXISTS certificates_responsible_ids_idx ON public.certificates USING gin (responsible_ids);

-- ═══════════════════════════════════════════════════════════════════════
-- View สาธารณะ — รวมชื่อผู้รับผิดชอบทุกคนเป็นข้อความเดียว คั่นด้วย ", "
-- เรียงตามลำดับที่บันทึกไว้ใน responsible_ids (WITH ORDINALITY)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW public.certificates_public AS
SELECT
  c.id, c.title, c.group_key, c.responsible_ids, c.cert_date, c.link_url,
  c.cover_source, c.cover_url, c.cover_drive_id, c.open_count,
  c.created_at, c.updated_at,
  COALESCE(rn.names, '') AS responsible_names
FROM public.certificates c
LEFT JOIN LATERAL (
  SELECT string_agg(
    COALESCE(
      NULLIF(btrim(p.full_name), ''),
      NULLIF(btrim(concat_ws(' ', p.title, p.first_name, p.last_name)), '')
    ), ', ' ORDER BY u.ord
  ) AS names
  FROM unnest(c.responsible_ids) WITH ORDINALITY AS u(id, ord)
  JOIN public.profiles p ON p.id = u.id
) rn ON true
WHERE c.is_published = true;

GRANT SELECT ON public.certificates_public TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
