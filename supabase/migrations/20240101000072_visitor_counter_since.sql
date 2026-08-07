-- ตัวนับผู้เข้าชมท้ายเว็บ — บอกด้วยว่าเริ่มนับตั้งแต่เมื่อไร
--
-- ตัวเลขสะสมลอย ๆ ไม่บอกอะไร ถ้าไม่รู้ว่านับมากี่วัน · ค่าเริ่มต้นใช้วันแรกที่มี
-- ข้อมูลจริงใน visit_daily (ไม่ต้องตั้งอะไรก็ถูกเสมอ) แต่ให้แอดมินกำหนดทับได้
-- เผื่อเว็บเปิดมาก่อนที่ระบบนับจะเริ่มทำงาน หรือเคยล้างข้อมูลสถิติทิ้ง

ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS visitor_counter_since date;

COMMENT ON COLUMN public.area_config.visitor_counter_since IS
  'วันที่แสดงว่า "เริ่มนับสถิติ" ท้ายเว็บ — NULL = ใช้วันแรกที่มีข้อมูลใน visit_daily';

-- ⚠️ 0062 REVOKE ทั้งตารางจาก anon แล้ว re-grant เป็นรายคอลัมน์
-- ลืมบรรทัดนี้ = ทางสำรองใน useAreaConfig.js ที่ query ตารางตรงจะพังเงียบ
GRANT SELECT (visitor_counter_since) ON public.area_config TO anon;

-- ── ตัวนับสาธารณะ: เพิ่ม since ──────────────────────────────────────────
-- ฟังก์ชันเป็น SECURITY DEFINER จึงอ่าน area_config ได้เองโดยไม่พึ่ง grant ข้างบน
-- (grant นั้นมีไว้ให้เส้นทางที่ query ตารางตรงเท่านั้น)
CREATE OR REPLACE FUNCTION public.get_visit_counter()
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'total', COALESCE((SELECT sum(views) FROM public.visit_daily), 0),
    'today', COALESCE((SELECT views FROM public.visit_daily
                       WHERE day = (now() AT TIME ZONE 'Asia/Bangkok')::date), 0),
    'since', COALESCE(
      (SELECT visitor_counter_since FROM public.area_config WHERE id = 1),
      (SELECT min(day) FROM public.visit_daily))
  );
$$;

REVOKE ALL ON FUNCTION public.get_visit_counter() FROM public;
GRANT EXECUTE ON FUNCTION public.get_visit_counter() TO anon, authenticated;

NOTIFY pgrst, 'reload schema';
