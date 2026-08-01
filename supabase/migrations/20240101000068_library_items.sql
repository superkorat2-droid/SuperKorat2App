-- ═══════════════════════════════════════════════════════════════════════
-- คลังหนังสือและคู่มือ — ศน./เจ้าหน้าที่ วางลิงก์ Drive สาธารณะแล้วขึ้นเป็นการ์ดภาพปก
--
-- เก็บแบบเดียวกับ newsletters (drive_url + file_id) เพราะภาพปกดึงจาก
-- https://drive.google.com/thumbnail?id=<file_id> ซึ่งคืน "หน้าแรกของ PDF" ให้เอง
-- จึงไม่ต้องเก็บจำนวนหน้าและไม่ต้องเรนเดอร์ PDF เอง (ดู driveThumb ใน useGoogleDrive.js)
--
-- ต่างจาก newsletters 2 อย่าง:
--   1) group_key  — กลุ่มงาน อ้างอิง key ใน area_config.personnel_groups
--   2) publisher_id — ผู้เผยแพร่ ผูกกับบัญชีสมาชิกจริง ไม่ใช่ข้อความอิสระ
--      (documents.publisher_name/publisher_dept ที่เป็น text ล้วนคือแบบที่เลี่ยง)
-- ═══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.library_items (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title        text NOT NULL,
  description  text,
  kind         text NOT NULL DEFAULT 'book'
               CHECK (kind IN ('book','handbook','research','regulation','other')),
  drive_url    text NOT NULL,
  file_id      text NOT NULL,
  mime_type    text,          -- ได้จาก Drive API ตอนกดตรวจลิงก์ (อาจว่างถ้าไม่ได้ตรวจ)
  cover_url    text,          -- ปกที่อัปทับเอง · NULL = ใช้หน้าแรกจาก Drive
  group_key    text,          -- key (ไม่ใช่ label) จาก area_config.personnel_groups
  publisher_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  year         int,           -- พ.ศ. เหมือน newsletters.year — ห้าม +543 ซ้ำตอนแสดง
  is_published boolean NOT NULL DEFAULT false,
  sort_order   int DEFAULT 99,
  created_by   uuid REFERENCES public.profiles(id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS library_items_group_idx     ON public.library_items(group_key);
CREATE INDEX IF NOT EXISTS library_items_publisher_idx ON public.library_items(publisher_id);
CREATE INDEX IF NOT EXISTS library_items_created_by_idx ON public.library_items(created_by);
CREATE INDEX IF NOT EXISTS library_items_published_idx ON public.library_items(is_published);

COMMENT ON COLUMN public.library_items.created_by IS
  'คนที่กรอกเข้าระบบ — ใช้ตัดสินสิทธิ์แก้/ลบใน RLS ห้ามเขียนทับตอน UPDATE (จะเป็นการโอนเจ้าของ)';
COMMENT ON COLUMN public.library_items.publisher_id IS
  'ผู้เผยแพร่ที่ได้เครดิต — คนละเรื่องกับ created_by ศน. คนหนึ่งลงหนังสือให้อีกคนได้';
COMMENT ON COLUMN public.library_items.group_key IS
  'key จาก area_config.personnel_groups (ไม่ใช่ label) เพื่อให้เปลี่ยนชื่อกลุ่มแล้วข้อมูลไม่ขาด';

ALTER TABLE public.library_items ENABLE ROW LEVEL SECURITY;

-- ── อ่าน ────────────────────────────────────────────────────────────────
-- คนทั่วไปเห็นเฉพาะที่เผยแพร่แล้ว · คนในเขต 4 บทบาทเห็นทุกแถวรวมฉบับร่าง
CREATE POLICY "library: public read" ON public.library_items
FOR SELECT TO anon, authenticated
USING (
  is_published = true
  OR EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = ANY (ARRAY['super_admin','admin','supervisor','staff'])
  )
);

-- ── เพิ่ม ───────────────────────────────────────────────────────────────
-- created_by ต้องเป็นตัวเองเสมอ แม้แต่ admin (แม่แบบจาก documents 0066)
CREATE POLICY "library: insert" ON public.library_items
FOR INSERT
WITH CHECK (
  created_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = ANY (ARRAY['super_admin','admin','supervisor','staff'])
  )
);

-- ── แก้ไข ───────────────────────────────────────────────────────────────
-- ต้องมีทั้ง USING (เลือกแถวที่แก้ได้) และ WITH CHECK (กันแก้แล้วโยนให้คนอื่น)
CREATE POLICY "library: update" ON public.library_items
FOR UPDATE
USING (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
  OR (created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role = ANY (ARRAY['supervisor','staff'])))
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
  OR (created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role = ANY (ARRAY['supervisor','staff'])))
);

-- ── ลบ ──────────────────────────────────────────────────────────────────
CREATE POLICY "library: delete" ON public.library_items
FOR DELETE
USING (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
  OR (created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role = ANY (ARRAY['supervisor','staff'])))
);

-- ═══════════════════════════════════════════════════════════════════════
-- View สำหรับหน้าสาธารณะ
--
-- ตรวจแล้ว: anon อ่าน profiles.full_name และ .department ได้จริง (0060 revoke
-- ทั้งตารางแล้ว re-grant เป็นรายคอลัมน์ ซึ่งรวม 2 ตัวนี้ไว้ ส่วน email อ่านไม่ได้)
-- จึง embed publisher:profiles(full_name) ตรง ๆ ก็ "พอทำงานได้" — แต่ไม่ทำ เพราะ
--   1) ผูกกับรายการคอลัมน์ที่ 0060 บังเอิญเปิดไว้ ใครไปรัดกุมเพิ่มวันหลังหน้านี้พังเงียบ
--   2) view การันตีเองว่าเห็นเฉพาะ is_published ไม่ต้องหวังให้ทุกที่ที่เรียกใส่ filter ครบ
--   3) ได้รูปร่างแบนชั้นเดียว ฝั่งหน้าเว็บกรอง/ค้นหาง่ายกว่า nested object
--
-- view ไม่ใช่ SECURITY INVOKER จึงรันด้วยสิทธิ์เจ้าของและข้าม RLS
-- **ตัวมันเองจึงต้องกรอง is_published เอง** และเปิดเฉพาะคอลัมน์ที่เผยแพร่ได้จริง
-- (แพทเทิร์นเดียวกับ personnel_public / works_public / awards_public)
-- ═══════════════════════════════════════════════════════════════════════
CREATE OR REPLACE VIEW public.library_public AS
SELECT
  l.id, l.title, l.description, l.kind,
  l.drive_url, l.file_id, l.mime_type, l.cover_url,
  l.group_key, l.publisher_id, l.year, l.sort_order,
  l.created_at, l.updated_at,
  COALESCE(
    NULLIF(btrim(p.full_name), ''),
    NULLIF(btrim(concat_ws(' ', p.title, p.first_name, p.last_name)), '')
  ) AS publisher_name,
  p.avatar_url AS publisher_avatar,
  p.position   AS publisher_position
FROM public.library_items l
LEFT JOIN public.profiles p ON p.id = l.publisher_id
WHERE l.is_published = true;

GRANT SELECT ON public.library_public TO anon, authenticated;
