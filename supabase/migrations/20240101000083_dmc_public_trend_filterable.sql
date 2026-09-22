-- Migration 83: ทำให้กราฟแนวโน้มท้ายหน้า /student-stats กรองตามตัวกรองบนหน้าได้
-- เดิม (migration 82) คืนแค่ยอดรวมสำเร็จรูปต่อรอบ กรองอะไรต่อไม่ได้เลย
-- เปลี่ยนให้คืนข้อมูลราย-โรงเรียนของทุกรอบที่เก็บถาวร+เปิดสาธารณะ (โครงสร้างเดียวกับ
-- get_dmc_public_stats()) เพื่อให้ฝั่งหน้าเว็บเอาตัวกรองชุดเดียวกัน (ศูนย์เครือข่าย/ระดับ/
-- ช่วงชั้น/สิทธิ์สอบ/โรงเรียน/อำเภอ) ไปคำนวณซ้ำกับทุกรอบได้เลย ไม่ต้องมี logic ใหม่
CREATE OR REPLACE FUNCTION public.get_dmc_public_trend()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER STABLE AS $$
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
        ), '[]'::jsonb
      ) AS uploads
    FROM public.dmc_periods p
    WHERE p.is_archived = true AND p.show_public = true
  ) t;
  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_dmc_public_trend() TO anon, authenticated;
