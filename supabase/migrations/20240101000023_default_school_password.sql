-- Migration 23: default school reset password
ALTER TABLE public.area_config
  ADD COLUMN IF NOT EXISTS default_school_password text DEFAULT 'Korat2@2569';
