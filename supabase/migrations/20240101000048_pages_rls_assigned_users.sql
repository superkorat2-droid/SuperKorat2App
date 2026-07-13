-- Migration 48: บังคับ pages.assigned_users จริงใน RLS (เดิมเช็คแค่ฝั่ง client)
-- เดิม "pages admin write" FOR ALL อนุญาตให้ staff/supervisor ทุกคนแก้ไขได้ทุกหน้า
-- ไม่ใช่แค่หน้าที่ตัวเองถูกมอบหมาย (assigned_users) — แยกเป็น insert/update/delete
-- insert/delete ยังคง admin-only, update เปิดให้ staff/supervisor ที่อยู่ใน assigned_users ด้วย

DROP POLICY IF EXISTS "pages admin write" ON public.pages;

CREATE POLICY "pages admin insert" ON public.pages FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin')
  ));

CREATE POLICY "pages admin or assigned update" ON public.pages FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR auth.uid() = ANY(assigned_users)
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR auth.uid() = ANY(assigned_users)
  );

CREATE POLICY "pages admin delete" ON public.pages FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin')
  ));
