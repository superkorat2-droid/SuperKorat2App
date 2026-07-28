-- ═══════════════════════════════════════════════════════════════════════
-- คลังภาพ (image_library) — สารบัญรูปที่ฝากไว้บน PHP host ของเขต
--
-- ใช้เก็บรูปแล้วคัดลอกลิงก์ไปป้อนให้ AI ทำเว็บ · เห็นและจัดการได้เฉพาะ admin
--
-- ตัวไฟล์รูปบน host เป็น URL สาธารณะโดยธรรมชาติ (AI ต้องโหลดได้)
-- สิ่งที่เป็นความลับคือ "สารบัญ" ว่ามีรูปอะไรบ้าง ตารางนี้จึงปิดสนิทจากทุกคน
-- ยกเว้น super_admin/admin
--
-- คู่กับ Edge Function `media-upload` ที่ถือความลับของ PHP host ไว้ฝั่งเซิร์ฟเวอร์
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.image_library (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- UNIQUE กันบันทึกรูปเดิมซ้ำถ้าเผลอกดอัปสองที
  url         text NOT NULL UNIQUE,
  filename    text,
  title       text NOT NULL DEFAULT '',
  tags        text[] NOT NULL DEFAULT '{}',
  size_bytes  bigint,
  mime        text,
  width       integer,
  height      integer,
  uploaded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS image_library_created_idx ON public.image_library (created_at DESC);
CREATE INDEX IF NOT EXISTS image_library_tags_idx    ON public.image_library USING gin (tags);

-- ── ปิดสนิท เข้าถึงได้เฉพาะ admin ──────────────────────────────────────
-- Supabase ตั้ง default privileges ให้ anon/authenticated บนตารางใหม่ใน public
-- ถ้าไม่ REVOKE จะอ่าน/เขียนตรงได้ (บทเรียนจาก 0059 / 0062 / 0064)
ALTER TABLE public.image_library ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.image_library FROM anon;

-- authenticated ต้องมีสิทธิ์ระดับตารางไว้ ไม่งั้น RLS ไม่มีโอกาสได้ทำงานเลย
-- ตัวกรองจริงอยู่ที่ policy ด้านล่าง (เฉพาะ super_admin/admin)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.image_library TO authenticated;

CREATE POLICY "image_library: admin only" ON public.image_library
FOR ALL
USING (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
);

COMMENT ON TABLE public.image_library IS
  'สารบัญรูปในคลังภาพ — ไฟล์จริงอยู่บน PHP host ของเขต อัป/ลบผ่าน Edge Function media-upload';
