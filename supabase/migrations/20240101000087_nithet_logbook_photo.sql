-- Migration 87: เพิ่มฟิลด์แนบภาพสมุดบันทึกการนิเทศ (ไม่บังคับ, แนบได้ภาพเดียว)
-- เป็นหลักฐานภายใน/ใช้ประกอบรายงาน A4 ตอนเบิกจ่าย ไม่ใช่เนื้อหาเผยแพร่สาธารณะ
-- จึงไม่เพิ่มเข้า view nithet_visits_public (ดูเหตุผลเดียวกับที่ view นั้นกรอง
-- จุดที่ควรพัฒนา/ข้อเสนอแนะ/ผู้รับการนิเทศ ออกไปแล้วใน migration 75)
ALTER TABLE public.nithet_visits
  ADD COLUMN logbook_photos jsonb NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.nithet_visits.logbook_photos IS
  '[{url, caption, w, h}] · ภาพหน้าสมุดบันทึกการนิเทศ ไม่บังคับแนบ · UI จำกัดไว้ที่ 1 รายการ (แนบใหม่แทนที่ของเดิม)';
