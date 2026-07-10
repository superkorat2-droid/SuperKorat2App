-- ข่าว: แก้บั๊ก user ทุกคนแก้/ลบข่าวของคนอื่นได้ — ให้เหลือแค่ admin หรือเจ้าของข่าวเท่านั้น
-- (ตามแบบเดียวกับ supervision_forms: 20240101000022_supervision_access_home.sql)

DROP POLICY IF EXISTS "news staff write" ON public.news;

-- INSERT: staff เท่านั้น, created_by ต้องเป็นตัวเอง
CREATE POLICY "news: insert"
  ON public.news FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid()
      AND role IN ('super_admin','admin','supervisor','staff')
    )
  );

-- UPDATE: admin=ทั้งหมด | เจ้าของ
CREATE POLICY "news: update"
  ON public.news FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR (created_by = auth.uid() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid()
      AND role IN ('supervisor','staff')
    ))
  );

-- DELETE: admin=ทั้งหมด | เจ้าของ
CREATE POLICY "news: delete"
  ON public.news FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin'))
    OR (created_by = auth.uid() AND EXISTS (
      SELECT 1 FROM public.profiles WHERE id = auth.uid()
      AND role IN ('supervisor','staff')
    ))
  );
