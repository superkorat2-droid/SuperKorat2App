-- Migration 89: สถิตินักเรียน DMC สาธารณะไม่นับโรงที่ปิด/ยุบแล้วที่ไม่มีนักเรียนในรอบนั้น
-- ไฟล์ DMC ระดับเขตยังมีแถวของโรงที่ปิดแล้ว (นักเรียน 0 คน) ติดมาด้วย เช่นรอบ 2569/1
-- มีบ้านโกรกไม้แดง + ภูทองวิทยา ยอด 0 → หน้า /student-stats และหน้าแรกนับเป็น 175 โรง
--
-- กติกาเดียวกับ migration 88: นับโรงที่ is_active หรือมีข้อมูลจริงในรอบนั้น (total > 0)
-- รอบเก่าที่โรงนั้นยังมีนักเรียนอยู่ (2568 มี 8 คน) จึงยังนับตามจริงของปีนั้น
-- ไม่แตะแถวใน dmc_school_uploads — กรองตอนอ่านอย่างเดียว เปิดโรงกลับมาก็เห็นครบเหมือนเดิม

CREATE OR REPLACE FUNCTION public.get_dmc_public_stats()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
  WHERE u.period_id = v_period.id
    AND (s.is_active OR COALESCE(u.total, 0) > 0);

  RETURN jsonb_build_object(
    'period',        to_jsonb(v_period),
    'uploads',       COALESCE(v_uploads, '[]'::jsonb),
    'total_schools', COALESCE(v_total, 0),
    'visibility',    v_period.visibility
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_dmc_public_trend()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
DECLARE
  v_result jsonb;
BEGIN
  SELECT COALESCE(jsonb_agg(t ORDER BY t.academic_year, t.semester), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      p.id, p.academic_year, p.semester, p.title, p.visibility,
      COALESCE(
        (SELECT jsonb_agg(
            jsonb_build_object(
              'school_id',   u.school_id,
              'school_name', s.name,
              'school_group', s.school_group,
              'district',    s.district,
              'level',       u.summary->>'level',
              'total',       u.total,
              'summary',     u.summary
            )
          )
         FROM public.dmc_school_uploads u
         JOIN public.schools s ON s.id = u.school_id
         WHERE u.period_id = p.id
           AND (s.is_active OR COALESCE(u.total, 0) > 0)
        ), '[]'::jsonb
      ) AS uploads
    FROM public.dmc_periods p
    WHERE p.is_archived = true AND p.show_public = true
  ) t;
  RETURN v_result;
END;
$function$;
