-- แก้การเว้นวรรคชื่อ: คำนำหน้าชื่อ (นางสาว/นาย ฯลฯ) ติดกับชื่อจริงตามธรรมเนียมไทย
-- เว้นวรรคเฉพาะระหว่างชื่อจริงกับนามสกุลเท่านั้น
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
      SELECT jsonb_agg(
        COALESCE(NULLIF(TRIM(CONCAT(p.title, p.first_name, CASE WHEN p.last_name > '' THEN ' ' || p.last_name ELSE '' END)), ''), p.full_name)
        ORDER BY p.first_name)
      FROM public.profiles p WHERE p.id = ANY(e.responsible_ids)
    ), '[]'::jsonb)
  ) ORDER BY e.start_date, e.start_time NULLS LAST), '[]'::jsonb)
  FROM public.nithet_events e
  WHERE e.show_public = true AND e.status <> 'cancelled';
$$;

GRANT EXECUTE ON FUNCTION public.get_nithet_events_public() TO anon, authenticated;
