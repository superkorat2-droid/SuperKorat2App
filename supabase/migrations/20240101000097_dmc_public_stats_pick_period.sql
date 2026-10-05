-- Migration 97: หน้า /student-stats เลือกรอบข้อมูลได้
-- get_dmc_public_stats(p_period_id) — ไม่ส่งค่า (NULL) = รอบล่าสุดที่เผยแพร่เหมือนเดิม จึงเรียกแบบไม่มีพารามิเตอร์ได้ต่อ
-- (หน้าแรก HomeView.fetchDmcStats ไม่ต้องแก้) · ส่งรหัสรอบที่ไม่ได้เผยแพร่/ไม่มีอยู่ → ถอยกลับไปรอบล่าสุด
-- คืน 'periods' = รอบที่เผยแพร่ทั้งหมด (ใหม่→เก่า) ให้หน้าสร้างช่องเลือกรอบ ไม่ต้องยิงอีกรอบ
-- กติกาโรงปิด/ยุบเหมือน migration 89: นับโรงที่ is_active หรือมีข้อมูลจริงในรอบนั้น

DROP FUNCTION IF EXISTS public.get_dmc_public_stats();

CREATE OR REPLACE FUNCTION public.get_dmc_public_stats(p_period_id uuid DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path = public
AS $function$
DECLARE
  v_period  public.dmc_periods%ROWTYPE;
  v_uploads jsonb;
  v_total   int;
  v_periods jsonb;
BEGIN
  IF p_period_id IS NOT NULL THEN
    SELECT * INTO v_period
    FROM public.dmc_periods
    WHERE id = p_period_id AND is_archived = true AND show_public = true;
  END IF;

  IF v_period.id IS NULL THEN
    SELECT * INTO v_period
    FROM public.dmc_periods
    WHERE is_archived = true AND show_public = true
    ORDER BY academic_year DESC, semester DESC LIMIT 1;
  END IF;

  IF v_period.id IS NULL THEN
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
  WHERE u.period_id = v_period.id
    AND (s.is_active OR COALESCE(u.total, 0) > 0);

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', p.id, 'academic_year', p.academic_year, 'semester', p.semester, 'title', p.title
    ) ORDER BY p.academic_year DESC, p.semester DESC
  ), '[]'::jsonb)
  INTO v_periods
  FROM public.dmc_periods p
  WHERE p.is_archived = true AND p.show_public = true;

  RETURN jsonb_build_object(
    'period',        to_jsonb(v_period),
    'periods',       v_periods,
    'uploads',       COALESCE(v_uploads, '[]'::jsonb),
    'total_schools', COALESCE(v_total, 0),
    'visibility',    v_period.visibility
  );
END;
$function$;

GRANT EXECUTE ON FUNCTION public.get_dmc_public_stats(uuid) TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
