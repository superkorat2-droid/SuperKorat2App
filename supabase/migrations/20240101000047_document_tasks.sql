-- ระบบธุรการ: งานเอกสารมอบหมายศึกษานิเทศก์ + คลังเอกสารภายใน + หน้าสาธารณะสำหรับโรงเรียน

-- ── สิทธิ์ธุรการ (แบบเดียวกับ can_publish_supervision) ──────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS can_manage_documents boolean NOT NULL DEFAULT false;

-- ── ประเภทหนังสือ (ตั้งค่าเองได้ แบบเดียวกับ personnel_groups) ──────────────
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='area_config' AND column_name='task_types') THEN
    ALTER TABLE public.area_config ADD COLUMN task_types jsonb DEFAULT NULL;
  END IF;
END $$;

UPDATE public.area_config
SET task_types = '[
  {"key":"announcement","label":"ประกาศ", "visible":true, "order":1},
  {"key":"order",        "label":"คำสั่ง",  "visible":true, "order":2},
  {"key":"other",        "label":"อื่นๆ",   "visible":true, "order":3}
]'::jsonb
WHERE task_types IS NULL;

-- ── ตารางงานเอกสาร ──────────────────────────────────────────────────────────
CREATE TABLE public.document_tasks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  task_type       text NOT NULL,
  department      text NOT NULL DEFAULT '',
  title           text NOT NULL,
  description     text NOT NULL DEFAULT '',
  source_link     text NOT NULL DEFAULT '',
  memo_link       text NOT NULL DEFAULT '',
  school_doc_link text NOT NULL DEFAULT '',
  is_public       boolean NOT NULL DEFAULT false,
  assigned_to     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status          text NOT NULL DEFAULT 'assigned'
                  CHECK (status IN ('assigned','in_progress','submitted','completed','cancelled')),
  created_by      uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_document_tasks_assigned_to ON public.document_tasks(assigned_to);
CREATE INDEX idx_document_tasks_status      ON public.document_tasks(status);

CREATE TRIGGER document_tasks_updated_at
  BEFORE UPDATE ON public.document_tasks
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.document_tasks ENABLE ROW LEVEL SECURITY;

-- SELECT: เสร็จแล้ว (completed) = คลังภายใน ให้ staff/supervisor/admin ทุกคนเห็น
--         ยังไม่เสร็จ = เห็นเฉพาะ admin/ธุรการ หรือเจ้าของงาน
CREATE POLICY "document_tasks: select"
  ON public.document_tasks FOR SELECT
  USING (
    (
      status = 'completed'
      AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role IN ('super_admin','admin','supervisor','staff'))
    )
    OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (role IN ('super_admin','admin') OR can_manage_documents = true))
    OR assigned_to = auth.uid()
  );

-- INSERT/UPDATE/DELETE: admin หรือธุรการ (can_manage_documents) เท่านั้น — ทำได้ทุกฟิลด์รวมถึง status
CREATE POLICY "document_tasks: insert"
  ON public.document_tasks FOR INSERT
  WITH CHECK (
    created_by = auth.uid()
    AND EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (role IN ('super_admin','admin') OR can_manage_documents = true))
  );

CREATE POLICY "document_tasks: update"
  ON public.document_tasks FOR UPDATE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (role IN ('super_admin','admin') OR can_manage_documents = true))
  );

CREATE POLICY "document_tasks: delete"
  ON public.document_tasks FOR DELETE
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND (role IN ('super_admin','admin') OR can_manage_documents = true))
  );

-- ── RPC: ทางลัดให้ศึกษานิเทศก์เปลี่ยนสถานะงานของตัวเอง (in_progress/submitted เท่านั้น) ──
CREATE OR REPLACE FUNCTION public.update_my_task_status(p_task_id uuid, p_status text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF p_status NOT IN ('in_progress','submitted') THEN
    RETURN jsonb_build_object('error', 'invalid_status');
  END IF;

  UPDATE public.document_tasks
  SET status = p_status
  WHERE id = p_task_id AND assigned_to = auth.uid() AND status IN ('assigned','in_progress');

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'not_found_or_not_allowed');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_my_task_status(uuid, text) TO authenticated;

-- ── RPC สาธารณะ: เอกสารที่ต้องส่งโรงเรียน (แยกจาก /download เดิมโดยสิ้นเชิง) ──
CREATE OR REPLACE FUNCTION public.get_school_documents_public()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER STABLE AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', d.id, 'task_type', d.task_type, 'department', d.department,
    'title', d.title, 'description', d.description,
    'school_doc_link', d.school_doc_link, 'created_at', d.created_at
  ) ORDER BY d.created_at DESC), '[]'::jsonb)
  FROM public.document_tasks d
  WHERE d.is_public = true AND d.status = 'completed';
$$;
GRANT EXECUTE ON FUNCTION public.get_school_documents_public() TO anon, authenticated;
