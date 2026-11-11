-- Migration 101: แอดมินจัดลำดับแบบนิเทศในเซกชันหน้าแรก
-- home_order = ลำดับที่แอดมินจัด (null = ยังไม่จัด)
-- เรียง: แบบที่ยังไม่จัด (เช่น แบบใหม่) ขึ้นก่อนตามลำดับเดิม (กำหนดส่งใกล้สุด → สร้างล่าสุด) แล้วตามด้วยแบบที่จัดแล้ว
-- ตอนรันครั้งแรกทุกแบบเป็น null → หน้าแรกเรียงเหมือนเดิมเป๊ะ · รันซ้ำได้

ALTER TABLE public.supervision_forms
  ADD COLUMN IF NOT EXISTS home_order int;

-- นิยามลอกจาก production (pg_get_functiondef, 11 พ.ย. 69) ต่างแค่ ORDER BY
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
    -- ยังไม่จัด (home_order null) ขึ้นก่อน → แล้วตามลำดับที่แอดมินจัด → สำรองด้วยกำหนดส่งใกล้สุด/สร้างล่าสุด
    ORDER BY (f.home_order IS NOT NULL), f.home_order ASC, f.deadline ASC NULLS LAST, f.created_at DESC
  ) INTO v_forms
  FROM public.supervision_forms f
  WHERE f.status = 'published' AND f.show_on_home = true;

  RETURN COALESCE(v_forms, '[]'::jsonb);
END;
$function$;
