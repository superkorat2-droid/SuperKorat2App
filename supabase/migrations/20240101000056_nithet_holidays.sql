-- วันหยุด (Holidays) — แสดงบนปฏิทินนิเทศเพื่อไม่ให้นัดงานชนวันหยุด
--
-- แยกตารางจาก nithet_events เพราะคนละความหมาย: วันหยุดไม่มีผู้รับผิดชอบ ไม่มีสถานะ
-- ไม่มีโรงเรียน และเป็นข้อมูลอ้างอิงของทั้งเขต (ใครสร้างก็เห็นเหมือนกันหมด)
-- ต่างจากกิจกรรมที่ผูกกับผู้สร้าง/ผู้รับผิดชอบ

CREATE TABLE public.nithet_holidays (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  title       text        NOT NULL,
  start_date  date        NOT NULL,
  end_date    date        NOT NULL,
  type        text        NOT NULL DEFAULT 'public'
                          CHECK (type IN ('public','school','special')),
  note        text        NOT NULL DEFAULT '',
  created_by  uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT nithet_holidays_date_order CHECK (end_date >= start_date)
);

-- กันเพิ่มซ้ำเป๊ะๆ ตอน import Excel รอบเดียวกันหลายครั้ง
CREATE UNIQUE INDEX idx_nithet_holidays_unique ON public.nithet_holidays(start_date, end_date, title);
CREATE INDEX idx_nithet_holidays_dates ON public.nithet_holidays(start_date, end_date);

CREATE TRIGGER nithet_holidays_updated_at
  BEFORE UPDATE ON public.nithet_holidays
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ── RLS ──────────────────────────────────────────────────────
-- อ่าน: ผู้ใช้ที่ล็อกอินทุกคน (หน้าสาธารณะใช้ RPC ด้านล่างแทน)
-- เขียน: admin ขึ้นไป — วันหยุดเป็นข้อมูลกลางของเขต ไม่ควรให้ทุกคนแก้
ALTER TABLE public.nithet_holidays ENABLE ROW LEVEL SECURITY;

CREATE POLICY "nithet_holidays: select"
  ON public.nithet_holidays FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "nithet_holidays: insert"
  ON public.nithet_holidays FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

CREATE POLICY "nithet_holidays: update"
  ON public.nithet_holidays FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

CREATE POLICY "nithet_holidays: delete"
  ON public.nithet_holidays FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
  );

-- ── RPC สาธารณะ ──────────────────────────────────────────────
-- หน้าแรก/หน้า /nithet ใช้ anon key ซึ่ง RLS ข้างบนบล็อก จึงต้องผ่าน SECURITY DEFINER
-- (pattern เดียวกับ get_nithet_events_public)
CREATE OR REPLACE FUNCTION public.get_nithet_holidays_public()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', h.id, 'title', h.title, 'type', h.type, 'note', h.note,
    'start_date', h.start_date, 'end_date', h.end_date
  ) ORDER BY h.start_date), '[]'::jsonb)
  FROM public.nithet_holidays h;
$$;

GRANT EXECUTE ON FUNCTION public.get_nithet_holidays_public() TO anon, authenticated;
