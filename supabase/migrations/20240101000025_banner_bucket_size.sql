-- Migration 25: เพิ่ม limit banners bucket เป็น 50MB สำหรับวิดีโอ
UPDATE storage.buckets
SET file_size_limit = 52428800  -- 50 MB
WHERE id = 'banners';
