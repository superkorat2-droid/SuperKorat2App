-- ปฏิทินนิเทศ (Supervision/Activity Calendar) — school visits + department activities
CREATE TABLE public.nithet_events (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  type           text        NOT NULL DEFAULT 'school_visit'
                             CHECK (type IN ('school_visit','meeting','training','other')),
  title          text        NOT NULL,
  description    text        NOT NULL DEFAULT '',
  start_date     date        NOT NULL,
  end_date       date        NOT NULL,
  start_time     time,
  end_time       time,
  school_id      uuid        REFERENCES public.schools(id) ON DELETE SET NULL,
  location       text        NOT NULL DEFAULT '',
  responsible_id uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  status         text        NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled','done','cancelled')),
  show_public    boolean     NOT NULL DEFAULT true,
  created_by     uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT nithet_events_date_order CHECK (end_date >= start_date),
  CONSTRAINT nithet_events_school_required CHECK (type <> 'school_visit' OR school_id IS NOT NULL)
);

CREATE INDEX idx_nithet_events_dates       ON public.nithet_events(start_date, end_date);
CREATE INDEX idx_nithet_events_school      ON public.nithet_events(school_id);
CREATE INDEX idx_nithet_events_responsible ON public.nithet_events(responsible_id);
CREATE INDEX idx_nithet_events_created_by  ON public.nithet_events(created_by);

-- reuse the existing trigger fn from 20240101000003_schools_v2.sql
CREATE TRIGGER nithet_events_updated_at
  BEFORE UPDATE ON public.nithet_events
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE public.nithet_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nithet_events: select"
  ON public.nithet_events FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR created_by = auth.uid()
    OR (show_public = true AND auth.role() = 'authenticated')
  );

CREATE POLICY "nithet_events: insert"
  ON public.nithet_events FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );

CREATE POLICY "nithet_events: update"
  ON public.nithet_events FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR (created_by = auth.uid() AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('supervisor','staff')))
  );

CREATE POLICY "nithet_events: delete"
  ON public.nithet_events FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR (created_by = auth.uid() AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('supervisor','staff')))
  );

-- ── Public RPC (anon-safe, joined + shaped payload) ──────────
CREATE OR REPLACE FUNCTION public.get_nithet_events_public()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', e.id, 'type', e.type, 'title', e.title, 'description', e.description,
    'start_date', e.start_date, 'end_date', e.end_date,
    'start_time', e.start_time, 'end_time', e.end_time,
    'location', e.location, 'status', e.status,
    'school', CASE WHEN s.id IS NOT NULL THEN jsonb_build_object('id', s.id, 'name', s.name, 'district', s.district) ELSE NULL END,
    'responsible_name', COALESCE(NULLIF(TRIM(CONCAT_WS(' ', p.title, p.first_name, p.last_name)), ''), p.full_name)
  ) ORDER BY e.start_date, e.start_time NULLS LAST), '[]'::jsonb)
  FROM public.nithet_events e
  LEFT JOIN public.schools  s ON s.id = e.school_id
  LEFT JOIN public.profiles p ON p.id = e.responsible_id
  WHERE e.show_public = true AND e.status <> 'cancelled';
$$;

GRANT EXECUTE ON FUNCTION public.get_nithet_events_public() TO anon, authenticated;
