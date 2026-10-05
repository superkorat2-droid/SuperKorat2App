-- Migration 95: ปักหมุดเกียรติบัตร — แสดงก่อนรายการอื่นในหน้าสาธารณะ
-- เพิ่มคอลัมน์ท้าย view เท่านั้น (CREATE OR REPLACE VIEW ต่อคอลัมน์ใหม่ได้เฉพาะท้ายรายการ)
ALTER TABLE public.certificates ADD COLUMN IF NOT EXISTS is_pinned boolean NOT NULL DEFAULT false;

CREATE OR REPLACE VIEW public.certificates_public AS
SELECT
  c.id, c.title, c.group_key, c.responsible_ids, c.cert_date, c.link_url,
  c.cover_source, c.cover_url, c.cover_drive_id, c.open_count,
  c.created_at, c.updated_at,
  COALESCE(rn.names, '') AS responsible_names,
  c.is_pinned
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
