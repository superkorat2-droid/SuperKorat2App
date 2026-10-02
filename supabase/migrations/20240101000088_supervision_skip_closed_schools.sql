-- Migration 88: แบบนิเทศไม่นับโรงเรียนที่ปิด/ยุบแล้ว (schools.is_active = false) เป็นเป้าหมาย
-- เดิมตัวหาร "ทุกโรงเรียน" = COUNT(*) FROM schools ทั้งหมด โรงที่ปิดไปจึงค้างอยู่ใน
-- "ยังไม่ตอบ" ตลอด และร้อยละไม่มีทางถึง 100
--
-- กติกา: โรงที่ปิดแล้วไม่นับ ยกเว้นโรงนั้นตอบแบบนี้ไว้ก่อนปิด (ไม่งั้นจำนวนที่ตอบ
-- จะเกินตัวหาร) — ใช้กติกาเดียวกับหน้าผลฝั่งแอดมิน AdminSupervisionResultsView
-- ใช้ทั้งกรณี target = 'all' และ 'selected' (เผื่อแบบที่ติ๊กโรงไว้ก่อนโรงนั้นถูกปิด)

CREATE OR REPLACE FUNCTION public.get_supervision_status_public(p_form_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  v_visibility text;
  v_target     text;
  v_target_sch uuid[];
  v_responded  jsonb;
  v_pending    jsonb;
  v_total      int := 0;
BEGIN
  SELECT status_visibility, target, target_schools
  INTO v_visibility, v_target, v_target_sch
  FROM public.supervision_forms
  WHERE id = p_form_id AND status = 'published';

  IF v_visibility IS NULL OR v_visibility = 'hidden' THEN
    RETURN jsonb_build_object('error', 'not_accessible');
  END IF;

  SELECT jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) ORDER BY s.name)
  INTO v_responded
  FROM public.supervision_responses sr
  JOIN public.schools s ON s.id = sr.school_id
  WHERE sr.form_id = p_form_id AND sr.is_complete = true AND sr.school_id IS NOT NULL;

  WITH done AS (
    SELECT DISTINCT sr.school_id
    FROM public.supervision_responses sr
    WHERE sr.form_id = p_form_id AND sr.is_complete = true AND sr.school_id IS NOT NULL
  ),
  targets AS (
    SELECT s.id, s.name, (d.school_id IS NOT NULL) AS responded
    FROM public.schools s
    LEFT JOIN done d ON d.school_id = s.id
    WHERE (v_target = 'all' OR s.id = ANY(v_target_sch))
      AND (s.is_active OR d.school_id IS NOT NULL)
  )
  SELECT COUNT(*)::int,
         jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name) ORDER BY t.name)
           FILTER (WHERE NOT t.responded)
  INTO v_total, v_pending
  FROM targets t;

  RETURN jsonb_build_object(
    'total',             v_total,
    'responded',         COALESCE(jsonb_array_length(v_responded), 0),
    'responded_schools', COALESCE(v_responded, '[]'::jsonb),
    'pending_schools',   COALESCE(v_pending,   '[]'::jsonb)
  );
END;
$function$;

-- การ์ดแบบนิเทศหน้าแรก: target_count ใช้กติกาเดียวกัน
CREATE OR REPLACE FUNCTION public.get_supervision_list_public()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE v_forms jsonb;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'id',               f.id,
      'title',            f.title,
      'description',      f.description,
      'deadline',         f.deadline,
      'allow_public',     f.allow_public,
      'public_token',     f.public_token,
      'respondent_type',  f.respondent_type,
      'status_visibility',f.status_visibility,
      'target',           f.target,
      'response_count',   (
        SELECT COUNT(*) FROM public.supervision_responses r
        WHERE r.form_id = f.id AND r.is_complete = true
      ),
      'target_count', (
        SELECT COUNT(*)::int FROM public.schools s
        WHERE (f.target = 'all' OR s.id = ANY(f.target_schools))
          AND (s.is_active OR EXISTS (
            SELECT 1 FROM public.supervision_responses r
            WHERE r.form_id = f.id AND r.school_id = s.id AND r.is_complete = true
          ))
      )
    )
    -- เรียงตาม deadline ใกล้สุดก่อน (null/ไม่มี deadline อยู่ท้าย)
    ORDER BY f.deadline ASC NULLS LAST, f.created_at DESC
  ) INTO v_forms
  FROM public.supervision_forms f
  WHERE f.status = 'published' AND f.show_on_home = true;

  RETURN COALESCE(v_forms, '[]'::jsonb);
END;
$function$;
