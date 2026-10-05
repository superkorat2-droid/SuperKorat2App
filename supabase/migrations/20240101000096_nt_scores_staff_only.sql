-- Migration 96: ผลคะแนน RT/NT/O-NET เห็นได้เฉพาะ ศน./เจ้าหน้าที่/แอดมินที่ล็อกอิน
-- (ผู้รับผิดชอบคะแนน O-NET ไม่ยินยอมให้เปิดเผยต่อสาธารณะ — แก้จากที่ migration 86 เปิดไว้)
--
-- ตารางคะแนนล็อกสิทธิ์เฉพาะเจ้าหน้าที่ไว้แล้ว (RLS ของ migration 84) ช่องที่รั่วมีทางเดียวคือ
-- ฟังก์ชัน SECURITY DEFINER นี้ที่เคย GRANT ให้ anon จึงแก้ที่ฟังก์ชัน:
--   1) ถอนสิทธิ์ anon/PUBLIC  2) ตรวจ role ในฟังก์ชันซ้ำอีกชั้น (verify_jwt/anon key กันไม่ได้ ต้องตรวจเอง)
-- ชื่อฟังก์ชันคงเดิม (get_nt_public_trend) เพื่อไม่ต้องแก้ผู้เรียก · show_public ยังใช้เลือกว่ารอบไหนขึ้นหน้าดูผล

CREATE OR REPLACE FUNCTION public.get_nt_public_trend()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT CASE
    WHEN NOT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff')
    ) THEN '[]'::jsonb
    ELSE (
      SELECT COALESCE(jsonb_agg(t ORDER BY t.academic_year), '[]'::jsonb)
      FROM (
        SELECT
          p.id, p.exam_type, p.grade_level, p.academic_year, p.title, p.subjects,
          COALESCE(
            (SELECT jsonb_agg(
                jsonb_build_object(
                  'school_id',    sc.school_id,
                  'school_name',  s.name,
                  'school_group', s.school_group,
                  'district',     s.district,
                  'scores',       sc.scores
                )
              )
             FROM public.nt_school_scores sc
             JOIN public.schools s ON s.id = sc.school_id
             WHERE sc.period_id = p.id
            ), '[]'::jsonb
          ) AS scores
        FROM public.nt_periods p
        WHERE p.show_public = true
      ) t
    )
  END;
$$;

REVOKE ALL ON FUNCTION public.get_nt_public_trend() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_nt_public_trend() TO authenticated;
