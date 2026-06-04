-- Migration 14: Page-level permissions
-- assigned_users: supervisor IDs ที่มีสิทธิ์แก้เนื้อหาหน้านี้
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='pages' AND column_name='assigned_users') THEN
    ALTER TABLE public.pages ADD COLUMN assigned_users uuid[] DEFAULT '{}';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_pages_assigned_users ON public.pages USING GIN (assigned_users);
