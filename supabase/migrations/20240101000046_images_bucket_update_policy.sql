-- แก้บั๊ก: เปลี่ยน/แทนที่รูปโปรไฟล์บุคลากรไม่ได้ ("new row violates row-level security policy")
-- สาเหตุ: path รูปโปรไฟล์คงที่ (avatars/<id>.webp) ครั้งแรกอัปโหลดสำเร็จเพราะเป็น INSERT ใหม่
-- แต่ครั้งถัดไปที่ path เดิมมีไฟล์อยู่แล้ว Supabase Storage upsert:true จะทำ UPDATE แทน ซึ่ง
-- storage.objects bucket 'images' มีแค่ policy SELECT/INSERT/DELETE ไม่มี UPDATE เลยโดนบล็อก
CREATE POLICY "images auth update" ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'images' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  )
  WITH CHECK (
    bucket_id = 'images' AND
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
  );
