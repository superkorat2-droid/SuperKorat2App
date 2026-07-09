-- ปฏิทินนิเทศ: รองรับการนิเทศหลายโรงเรียนในกิจกรรมเดียว
ALTER TABLE public.nithet_events ADD COLUMN IF NOT EXISTS school_ids uuid[] NOT NULL DEFAULT '{}';

UPDATE public.nithet_events SET school_ids = ARRAY[school_id] WHERE school_id IS NOT NULL;

ALTER TABLE public.nithet_events DROP CONSTRAINT IF EXISTS nithet_events_school_required;
DROP INDEX IF EXISTS idx_nithet_events_school;
ALTER TABLE public.nithet_events DROP COLUMN IF EXISTS school_id;

ALTER TABLE public.nithet_events ADD CONSTRAINT nithet_events_school_required
  CHECK (type <> 'school_visit' OR array_length(school_ids, 1) > 0);

CREATE INDEX IF NOT EXISTS idx_nithet_events_school_ids ON public.nithet_events USING GIN (school_ids);

-- ── Public RPC: คืน schools เป็น array แทนโรงเรียนเดียว ──────────
CREATE OR REPLACE FUNCTION public.get_nithet_events_public()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', e.id, 'type', e.type, 'title', e.title, 'description', e.description,
    'start_date', e.start_date, 'end_date', e.end_date,
    'start_time', e.start_time, 'end_time', e.end_time,
    'location', e.location, 'status', e.status,
    'schools', COALESCE((
      SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name, 'district', s.district) ORDER BY s.name)
      FROM public.schools s WHERE s.id = ANY(e.school_ids)
    ), '[]'::jsonb),
    'responsible_group', NULLIF(e.responsible_group, ''),
    'responsible_names', COALESCE((
      SELECT jsonb_agg(COALESCE(NULLIF(TRIM(CONCAT_WS(' ', p.title, p.first_name, p.last_name)), ''), p.full_name) ORDER BY p.first_name)
      FROM public.profiles p WHERE p.id = ANY(e.responsible_ids)
    ), '[]'::jsonb)
  ) ORDER BY e.start_date, e.start_time NULLS LAST), '[]'::jsonb)
  FROM public.nithet_events e
  WHERE e.show_public = true AND e.status <> 'cancelled';
$$;

GRANT EXECUTE ON FUNCTION public.get_nithet_events_public() TO anon, authenticated;
