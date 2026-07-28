-- ═══════════════════════════════════════════════════════════════════════
-- เอกสาร/ดาวน์โหลด: จำกัดการแก้/ลบให้เป็นของเจ้าของ (เดิมใครในเขตก็แก้ของคนอื่นได้)
--
-- ของเดิมมี policy เดียว "documents staff write" FOR ALL ที่เช็คแค่บทบาท
-- (super_admin/admin/supervisor/staff) โดย **ไม่ดูเลยว่าใครเป็นคนสร้าง**
-- ทั้งที่ตารางมีคอลัมน์ created_by บันทึกไว้อยู่แล้ว
-- → ศึกษานิเทศก์หรือ staff คนไหนก็แก้และลบเอกสารของคนอื่นได้หมด
--
-- ตารางอื่นในระบบ (news / media / newsletters / awards / works) เช็คเจ้าของ
-- กันหมดแล้ว documents เป็นตัวเดียวที่หลุดแพตเทิร์น
--
-- กติกาใหม่ = ชุดเดียวกับ news เป๊ะ ๆ:
--   เพิ่ม  : ต้องเป็นคนในเขต 4 บทบาท และ created_by ต้องเป็นตัวเอง
--   แก้/ลบ : super_admin กับ admin ทำได้ทุกชิ้น · ศน./staff ทำได้เฉพาะของตัวเอง
--
-- เอกสารเก่าที่ created_by เป็น NULL จะเหลือแค่ admin ที่แก้ได้ (ตรวจ production
-- แล้วตอนนี้ทุกแถวมี created_by ครบ ไม่มีของกำพร้า)
-- ═══════════════════════════════════════════════════════════════════════

DROP POLICY IF EXISTS "documents staff write" ON public.documents;

-- ── เพิ่ม ───────────────────────────────────────────────────────────────
CREATE POLICY "documents: insert" ON public.documents
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
CREATE POLICY "documents: update" ON public.documents
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
CREATE POLICY "documents: delete" ON public.documents
FOR DELETE
USING (
  EXISTS (SELECT 1 FROM public.profiles
          WHERE id = auth.uid() AND role = ANY (ARRAY['super_admin','admin']))
  OR (created_by = auth.uid()
      AND EXISTS (SELECT 1 FROM public.profiles
                  WHERE id = auth.uid() AND role = ANY (ARRAY['supervisor','staff'])))
);

COMMENT ON COLUMN public.documents.created_by IS
  'เจ้าของเอกสาร — ใช้ตัดสินสิทธิ์แก้/ลบใน RLS ห้ามเขียนทับตอน UPDATE (จะเป็นการโอนเจ้าของ)';
