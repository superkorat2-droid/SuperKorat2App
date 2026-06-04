-- Migration 19: เพิ่ม section type ใน supervision_questions
ALTER TABLE public.supervision_questions
  DROP CONSTRAINT IF EXISTS supervision_questions_type_check;

ALTER TABLE public.supervision_questions
  ADD CONSTRAINT supervision_questions_type_check
  CHECK (type IN ('text','textarea','choice','multi_choice','rating','yes_no','number','section'));
