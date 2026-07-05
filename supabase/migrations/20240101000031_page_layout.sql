-- เพิ่ม layout option ให้ pages (narrow / medium / wide)
ALTER TABLE pages
  ADD COLUMN IF NOT EXISTS layout TEXT NOT NULL DEFAULT 'narrow';
