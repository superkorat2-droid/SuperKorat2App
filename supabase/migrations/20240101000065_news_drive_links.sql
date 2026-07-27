-- ═══════════════════════════════════════════════════════════════════════
-- ข่าว: โฟลเดอร์ Drive + ไฟล์แนบหลายลิงก์ที่ตั้งชื่อได้
--
-- เดิมข่าวแนบได้ลิงก์เดียว (file_url) และช่อง embed รับได้แค่ไฟล์เดี่ยว
-- ไม่ใช่ทั้งโฟลเดอร์ เวลามีเอกสารประกอบหลายไฟล์จึงต้องยัดลิงก์เดียว
--
-- ทั้งสองคอลัมน์เป็นของใหม่ที่มี default — ข่าวเก่าทุกแถวได้ค่าว่างทันที
-- ไม่มีอะไรพัง และ RLS/grant ไม่ต้องแตะเพราะ news ให้สิทธิ์ระดับตาราง
-- (ต่างจาก profiles / area_config ที่เป็น column-level grant)
-- ═══════════════════════════════════════════════════════════════════════

ALTER TABLE public.news
  -- โครงเดียวกับบล็อก Drive ของหน้า CMS เป๊ะ ๆ จะได้ใช้ DriveFolderEditor
  -- และ DriveFolderBrowser ตัวเดิมได้เลย:
  -- { url, folder_id, title, view, cols, rows, rows_list, show_search, allow_subfolders }
  ADD COLUMN IF NOT EXISTS drive jsonb NOT NULL DEFAULT '{}'::jsonb,
  -- [{ label, url }] — label เว้นว่างได้ หน้าเว็บจะตั้งชื่อให้เองตามชนิดไฟล์
  ADD COLUMN IF NOT EXISTS links jsonb NOT NULL DEFAULT '[]'::jsonb;

-- ── ย้ายไฟล์แนบเดิมเข้าลิสต์ใหม่ ────────────────────────────────────────
-- ถ้าไม่ย้าย ข่าวเก่าจะไม่มีไฟล์แนบโผล่บนหน้าเว็บอีกเลยเมื่อ UI เปลี่ยนไปอ่าน links
-- เงื่อนไข links = '[]' กันเขียนทับกรณีรัน migration ซ้ำ
UPDATE public.news
SET links = jsonb_build_array(jsonb_build_object('label', '', 'url', btrim(file_url)))
WHERE COALESCE(btrim(file_url), '') <> ''
  AND links = '[]'::jsonb;

-- คง file_url ไว้ ไม่ลบทิ้ง — ฟอร์มยังเขียนค่าลิงก์แรกลงไปด้วยเป็นตาข่ายกันพลาด
-- ให้โค้ดเก่าที่อาจตกหล่น (เช่นป้ายคลิปหนีบในการ์ดข่าว) ยังทำงานได้เหมือนเดิม

COMMENT ON COLUMN public.news.drive IS 'โฟลเดอร์ Google Drive ที่แนบกับข่าว — โครงเดียวกับบล็อก drive ของหน้า CMS';
COMMENT ON COLUMN public.news.links IS 'ไฟล์แนบ/ลิงก์เพิ่มเติม [{label, url}] — ย้ายมาจาก file_url เดิมใน migration 0065';
