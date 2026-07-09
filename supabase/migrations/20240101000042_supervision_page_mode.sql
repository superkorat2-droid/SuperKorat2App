-- แบบนิเทศ: เลือกได้ว่าจะแสดงคำถามต่อเนื่องหน้าเดียว หรือแยกหน้าตามหัวข้อส่วน (section)
ALTER TABLE public.supervision_forms ADD COLUMN IF NOT EXISTS page_mode text NOT NULL DEFAULT 'continuous'
  CHECK (page_mode IN ('continuous','paginated'));
