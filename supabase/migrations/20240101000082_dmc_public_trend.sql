-- Migration 82: สาธารณะ — แนวโน้มนักเรียนข้ามภาคเรียน (เฉพาะรอบที่เก็บถาวร+เปิดสาธารณะ)
-- คืนแค่ตัวเลขรวมต่อรอบ (ไม่มีรายโรง ไม่มี PII) ใช้แสดงกราฟแนวโน้มท้ายหน้า /student-stats
-- แบบ static ไม่ผูกกับตัวกรองใดๆ บนหน้า
CREATE OR REPLACE FUNCTION public.get_dmc_public_trend()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(jsonb_agg(t ORDER BY t.academic_year, t.semester), '[]'::jsonb)
  FROM (
    SELECT
      p.id, p.academic_year, p.semester, p.title,
      COUNT(u.id)::int AS schools,
      COALESCE(SUM(u.total), 0)::int AS total,
      COALESCE(SUM((u.summary->'gender'->>'male')::int), 0)::int AS male,
      COALESCE(SUM((u.summary->'gender'->>'female')::int), 0)::int AS female
    FROM public.dmc_periods p
    LEFT JOIN public.dmc_school_uploads u ON u.period_id = p.id
    WHERE p.is_archived = true AND p.show_public = true
    GROUP BY p.id, p.academic_year, p.semester, p.title
  ) t;
$$;
GRANT EXECUTE ON FUNCTION public.get_dmc_public_trend() TO anon, authenticated;
