-- แผนการนิเทศอย่างเป็นทางการ (มีเลขที่คำสั่ง) บน nithet_events
--
-- เดิม nithet_events ใช้เป็นปฏิทินนัดหมายเฉย ๆ ทุกคน (super_admin/admin/supervisor/staff)
-- สร้าง/แก้ของตัวเองได้เท่ากันหมด ตอนนี้ต้องการให้ "หัวหน้างานนิเทศ" คนเดียว/บางคน เป็นผู้กำหนด
-- แผนที่ผูกกับคำสั่งจริง (เลขที่คำสั่ง/ลงวันที่/ลิงก์คำสั่ง/เอกสารประกอบ/ประเด็นย่อย) ส่วน ศน. คนอื่น
-- ยังสร้างนัดหมายของตัวเองได้ปกติทุกอย่าง แค่กรอกฟิลด์คำสั่งเหล่านี้ไม่ได้ — ล็อกระดับฟิลด์
-- ผ่าน trigger ไม่ใช่ล็อกทั้งแถว จึงไม่ต้องแตะ RLS เดิมเลย

ALTER TABLE public.nithet_events
  ADD COLUMN IF NOT EXISTS order_number text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS order_date   date,
  ADD COLUMN IF NOT EXISTS order_link   text NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS doc_links    jsonb NOT NULL DEFAULT '[]'::jsonb, -- [{url,label}] เอกสารประกอบคำสั่ง หลายไฟล์
  ADD COLUMN IF NOT EXISTS topics       text[] NOT NULL DEFAULT '{}';      -- ประเด็นนิเทศย่อยที่กำหนดไว้ล่วงหน้า

COMMENT ON COLUMN public.nithet_events.order_number IS
  'เลขที่คำสั่งนิเทศ — กรอกได้เฉพาะ super_admin/admin หรือคนที่มี profiles.can_manage_nithet_plan (บังคับผ่าน trigger ด้านล่าง)';
COMMENT ON COLUMN public.nithet_events.doc_links IS
  '[{url,label}] เอกสารประกอบคำสั่ง แยกจาก order_link (ลิงก์คำสั่งตัวหลัก)';

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_manage_nithet_plan boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN public.profiles.can_manage_nithet_plan IS
  'สิทธิ์กำหนดแผนการนิเทศ (เลขที่คำสั่ง/ลิงก์คำสั่ง/ประเด็นย่อย) บน nithet_events — มอบแยกจาก can_approve_nithet';

-- ── trigger ล็อกฟิลด์คำสั่ง ───────────────────────────────────
-- คนที่ไม่ใช่ super_admin/admin และไม่มี can_manage_nithet_plan พยายามกรอก/แก้ฟิลด์คำสั่ง
-- จะถูกรีเซ็ตเงียบ ๆ (INSERT → ว่างเสมอ, UPDATE → คืนค่าเดิม)
--
-- ⚠️ ตัว trigger function ต้อง "ไม่ใช่" SECURITY DEFINER — ถ้าเป็น SECURITY DEFINER แล้ว
-- current_user ภายในฟังก์ชันจะกลายเป็นเจ้าของฟังก์ชัน (postgres) เสมอไม่ว่าใครเรียก ทำให้
-- เช็คสิทธิ์อิงตัวผู้ใช้จริงไม่ได้เลย (ต่างจาก pattern current_user check ของ nithet_visits ที่
-- ใช้แยก "มาจาก RPC หรือมาจากผู้ใช้ตรง ๆ" — ที่นี่ไม่มี RPC มาเกี่ยวข้อง เช็คสิทธิ์ตรง ๆ ทุกครั้งพอ)
-- อ่าน profiles ผ่านฟังก์ชันช่วย SECURITY DEFINER แยกต่างหาก (เหมือน is_area_admin()) แทน
CREATE OR REPLACE FUNCTION public.can_manage_nithet_plan()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND (p.role IN ('super_admin','admin') OR p.can_manage_nithet_plan)
  );
$$;
GRANT EXECUTE ON FUNCTION public.can_manage_nithet_plan() TO authenticated;

CREATE OR REPLACE FUNCTION public.nithet_events_order_guard()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF public.can_manage_nithet_plan() THEN RETURN NEW; END IF;

  IF TG_OP = 'INSERT' THEN
    NEW.order_number := '';
    NEW.order_date   := NULL;
    NEW.order_link   := '';
    NEW.doc_links    := '[]'::jsonb;
    NEW.topics       := '{}';
  ELSE
    NEW.order_number := OLD.order_number;
    NEW.order_date   := OLD.order_date;
    NEW.order_link   := OLD.order_link;
    NEW.doc_links    := OLD.doc_links;
    NEW.topics       := OLD.topics;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_nithet_events_order_guard ON public.nithet_events;
CREATE TRIGGER trg_nithet_events_order_guard
  BEFORE INSERT OR UPDATE ON public.nithet_events
  FOR EACH ROW EXECUTE FUNCTION public.nithet_events_order_guard();

NOTIFY pgrst, 'reload schema';
