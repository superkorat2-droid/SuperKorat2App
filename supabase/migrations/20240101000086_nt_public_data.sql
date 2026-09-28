-- Migration 86: เปิดเผยผลคะแนน NT ต่อสาธารณะเต็มรูปแบบ (ผู้รับผิดชอบ NT อนุมัติแล้ว 28 ก.ย. 69)
-- แทนที่ get_nt_public_trend() เดิม (migration 85 คืนแค่ค่าเฉลี่ยรวมสำเร็จรูป กรองต่อไม่ได้)
-- ให้คืนข้อมูลราย-โรงเรียนของทุกรอบที่ show_public=true แบบเดียวกับ get_dmc_public_trend()
-- เพื่อให้หน้า /nt-scores เอาไปกรอง (อำเภอ/ศูนย์เครือข่าย/โรงเรียน) และคำนวณกราฟแนวโน้มเองได้
CREATE OR REPLACE FUNCTION public.get_nt_public_trend()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(jsonb_agg(t ORDER BY t.academic_year), '[]'::jsonb)
  FROM (
    SELECT
      p.id, p.exam_type, p.grade_level, p.academic_year, p.title, p.subjects,
      COALESCE(
        (SELECT jsonb_agg(
            jsonb_build_object(
              'school_id',   sc.school_id,
              'school_name', s.name,
              'school_group', s.school_group,
              'district',    s.district,
              'scores',      sc.scores
            )
          )
         FROM public.nt_school_scores sc
         JOIN public.schools s ON s.id = sc.school_id
         WHERE sc.period_id = p.id
        ), '[]'::jsonb
      ) AS scores
    FROM public.nt_periods p
    WHERE p.show_public = true
  ) t;
$$;
GRANT EXECUTE ON FUNCTION public.get_nt_public_trend() TO anon, authenticated;
