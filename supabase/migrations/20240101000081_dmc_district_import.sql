-- Migration 81: DMC district-wide bulk import support
-- ไม่มีตารางใหม่ — แค่ให้ RPC สาธารณะคืน "ศูนย์เครือข่าย" (school_group) และ "อำเภอ" (district)
-- จริงจากตาราง schools (ไม่ใช่จาก jsonb summary ที่ไม่เคยมีค่านี้) เพื่อให้กรอง/แสดงผล
-- ตามศูนย์เครือข่ายและระดับได้ทั้งหน้า public และหน้าแรก
CREATE OR REPLACE FUNCTION public.get_dmc_public_stats()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_period  public.dmc_periods%ROWTYPE;
  v_uploads jsonb;
  v_total   int;
BEGIN
  SELECT * INTO v_period
  FROM public.dmc_periods
  WHERE is_archived = true AND show_public = true
  ORDER BY academic_year DESC, semester DESC LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'no_public_data');
  END IF;

  SELECT jsonb_agg(
    jsonb_build_object(
      'school_id',    u.school_id,
      'school_name',  s.name,
      'school_group', s.school_group,
      'district',     s.district,
      'level',        u.summary->>'level',
      'total',        u.total,
      'summary',      u.summary,
      'uploaded_at',  u.uploaded_at
    ) ORDER BY s.name
  ),
  COUNT(*)::int
  INTO v_uploads, v_total
  FROM public.dmc_school_uploads u
  JOIN public.schools s ON s.id = u.school_id
  WHERE u.period_id = v_period.id;

  RETURN jsonb_build_object(
    'period',        to_jsonb(v_period),
    'uploads',       COALESCE(v_uploads, '[]'::jsonb),
    'total_schools', COALESCE(v_total, 0),
    'visibility',    v_period.visibility
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_dmc_public_stats() TO anon, authenticated;
