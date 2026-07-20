-- Migration 54: ระยะเวลาแสดงต่อแบนเนอร์ (วินาที) — เดิม HomeView.vue เลื่อนสไลด์ทุก 7 วิคงที่
-- เท่ากันหมดไม่ว่ารูปหรือวิดีโอ ทำให้แบนเนอร์วิดีโอเปลี่ยนเร็วเกินไปก่อนดูจบ
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='banners' AND column_name='duration_seconds') THEN
    ALTER TABLE public.banners ADD COLUMN duration_seconds int NOT NULL DEFAULT 7;
  END IF;
END $$;
