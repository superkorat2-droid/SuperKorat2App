-- Migration 85: RPC สาธารณะสำหรับกราฟแนวโน้มผลคะแนน NT บนหน้าแรก
-- คืนเฉพาะรอบที่ show_public = true — ค่าเฉลี่ยรวม (overall) ต่อรอบเท่านั้น
-- (รายละเอียด/ตัวกรองเต็มอยู่ที่ /dashboard/nt-trend ซึ่งต้อง login เป็นบุคลากรเขต)
CREATE OR REPLACE FUNCTION public.get_nt_public_trend()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'period_id',     p.id,
      'exam_type',     p.exam_type,
      'grade_level',   p.grade_level,
      'academic_year', p.academic_year,
      'title',         p.title,
      'avg_overall_pct', sub.avg_pct
    ) ORDER BY p.academic_year
  ), '[]'::jsonb)
  FROM public.nt_periods p
  JOIN LATERAL (
    SELECT AVG((s.scores->'overall'->>'pct')::numeric) AS avg_pct
    FROM public.nt_school_scores s
    WHERE s.period_id = p.id
  ) sub ON true
  WHERE p.show_public = true AND sub.avg_pct IS NOT NULL;
$$;
GRANT EXECUTE ON FUNCTION public.get_nt_public_trend() TO anon, authenticated;
