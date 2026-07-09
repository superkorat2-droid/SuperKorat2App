-- ปฏิทินนิเทศ: รองรับผู้รับผิดชอบหลายคน หรือมอบทั้งกลุ่ม
ALTER TABLE public.nithet_events ADD COLUMN IF NOT EXISTS responsible_ids uuid[] NOT NULL DEFAULT '{}';
ALTER TABLE public.nithet_events ADD COLUMN IF NOT EXISTS responsible_group text NOT NULL DEFAULT '';

-- ย้ายข้อมูลเดิมจาก responsible_id (คนเดียว) เข้า responsible_ids (array)
UPDATE public.nithet_events
SET responsible_ids = ARRAY[responsible_id]
WHERE responsible_id IS NOT NULL;

ALTER TABLE public.nithet_events DROP COLUMN IF EXISTS responsible_id;

CREATE INDEX IF NOT EXISTS idx_nithet_events_responsible_ids ON public.nithet_events USING GIN (responsible_ids);

-- ── Public RPC: คืนชื่อผู้รับผิดชอบหลายคน + ชื่อกลุ่ม ──────────
CREATE OR REPLACE FUNCTION public.get_nithet_events_public()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', e.id, 'type', e.type, 'title', e.title, 'description', e.description,
    'start_date', e.start_date, 'end_date', e.end_date,
    'start_time', e.start_time, 'end_time', e.end_time,
    'location', e.location, 'status', e.status,
    'school', CASE WHEN s.id IS NOT NULL THEN jsonb_build_object('id', s.id, 'name', s.name, 'district', s.district) ELSE NULL END,
    'responsible_group', NULLIF(e.responsible_group, ''),
    'responsible_names', COALESCE((
      SELECT jsonb_agg(COALESCE(NULLIF(TRIM(CONCAT_WS(' ', p.title, p.first_name, p.last_name)), ''), p.full_name) ORDER BY p.first_name)
      FROM public.profiles p WHERE p.id = ANY(e.responsible_ids)
    ), '[]'::jsonb)
  ) ORDER BY e.start_date, e.start_time NULLS LAST), '[]'::jsonb)
  FROM public.nithet_events e
  LEFT JOIN public.schools  s ON s.id = e.school_id
  WHERE e.show_public = true AND e.status <> 'cancelled';
$$;

GRANT EXECUTE ON FUNCTION public.get_nithet_events_public() TO anon, authenticated;
