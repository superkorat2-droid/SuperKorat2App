-- Migration 33: contact_messages — เก็บข้อความจากฟอร์ม "ส่งข้อความถึงกลุ่มนิเทศ" (/contact)
CREATE TABLE IF NOT EXISTS public.contact_messages (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name       text NOT NULL,
  position   text DEFAULT '',
  phone      text DEFAULT '',
  email      text NOT NULL,
  subject    text NOT NULL,
  message    text NOT NULL,
  is_read    boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  DROP POLICY IF EXISTS "contact_messages public insert" ON public.contact_messages;
  DROP POLICY IF EXISTS "contact_messages staff read"    ON public.contact_messages;
  DROP POLICY IF EXISTS "contact_messages staff manage"  ON public.contact_messages;
END $$;

-- ใครก็ส่งข้อความได้ (แม้ไม่ได้ล็อกอิน) แต่อ่านไม่ได้
CREATE POLICY "contact_messages public insert" ON public.contact_messages FOR INSERT WITH CHECK (true);

-- staff อ่าน/อัปเดต(is_read)/ลบได้
CREATE POLICY "contact_messages staff read" ON public.contact_messages FOR SELECT
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));
CREATE POLICY "contact_messages staff manage" ON public.contact_messages FOR UPDATE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));
CREATE POLICY "contact_messages staff delete" ON public.contact_messages FOR DELETE
  USING (EXISTS (SELECT 1 FROM public.profiles WHERE id=auth.uid() AND role IN ('super_admin','admin','supervisor','staff')));

CREATE INDEX IF NOT EXISTS idx_contact_messages_created ON public.contact_messages(created_at DESC);
