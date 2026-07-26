-- จำกัดสิทธิ์แก้ไข/ลบจดหมายข่าว: ศน./เจ้าหน้าที่ แก้ได้เฉพาะรายการที่ตัวเองสร้าง
--
-- เดิมมี policy เดียว "newsletters: write" แบบ FOR ALL ที่ให้ super_admin/admin/
-- supervisor/staff ทำได้ทุกอย่างกับทุกแถว — ศน. คนหนึ่งจึงลบของ ศน. อีกคน
-- หรือของโรงเรียนได้ ตอนนี้แยกเป็น INSERT / UPDATE / DELETE เพื่อคุมคนละแบบ
--
-- สรุปสิทธิ์หลังแก้:
--   super_admin, admin  → ทุกแถว (ไม่เปลี่ยน)
--   supervisor, staff   → เพิ่มได้ทุกโรงเรียน แต่แก้/ลบได้เฉพาะที่ตัวเองสร้าง
--   ผู้ใช้โรงเรียน       → ของโรงเรียนตัวเอง (ไม่เปลี่ยน — รวมถึงที่ ศน. สร้างให้)
--
-- หมายเหตุ: แถวเดิมที่ created_by เป็น NULL (สร้างก่อน migration นี้ ตอนที่ frontend
-- ยังไม่ได้ส่งค่ามา) ศน. จะแก้ไม่ได้ ต้องให้ admin แก้แทน — ตั้งใจให้เป็นแบบนี้
-- เพราะเดาไม่ได้ว่าใครเป็นคนสร้าง และมีแถวเก่าไม่มาก

DROP POLICY IF EXISTS "newsletters: write" ON public.newsletters;

-- ── INSERT ────────────────────────────────────────────────────
-- ศน./เจ้าหน้าที่ ต้องระบุ created_by เป็นตัวเองเท่านั้น กันสร้างแล้วสวมชื่อคนอื่น
CREATE POLICY "newsletters: insert"
  ON public.newsletters FOR INSERT
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR (
      created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role IN ('supervisor','staff'))
    )
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.school_id = newsletters.school_id)
  );

-- ── UPDATE ────────────────────────────────────────────────────
CREATE POLICY "newsletters: update"
  ON public.newsletters FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.school_id = newsletters.school_id)
  )
  -- กันแก้แล้วโยน created_by ให้คนอื่น (admin ยังทำได้ตามปกติ)
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.school_id = newsletters.school_id)
  );

-- ── DELETE ────────────────────────────────────────────────────
CREATE POLICY "newsletters: delete"
  ON public.newsletters FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR created_by = auth.uid()
    OR EXISTS (SELECT 1 FROM public.profiles p
               WHERE p.id = auth.uid() AND p.school_id = newsletters.school_id)
  );

-- ค้นรายการ "ของฉัน" ในหน้าจัดการได้เร็วขึ้น
CREATE INDEX IF NOT EXISTS newsletters_created_by_idx ON public.newsletters(created_by);
