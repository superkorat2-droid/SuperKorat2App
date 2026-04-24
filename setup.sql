-- ==========================================
-- 1. PROFILES & ADMIN ROLE SETUP
-- ==========================================

-- Add is_admin column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;

-- Create a helper function to check if the current user is an admin
-- Using SECURITY DEFINER to allow checking even if RLS is strict
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (SELECT is_admin FROM public.profiles WHERE id = auth.uid());
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update RLS policies for profiles table
DROP POLICY IF EXISTS "Admins can manage all profiles" ON profiles;
CREATE POLICY "Admins can manage all profiles" ON profiles
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Update RLS policies for contents table
DROP POLICY IF EXISTS "Admins can manage all contents" ON contents;
CREATE POLICY "Admins can manage all contents" ON contents
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());


-- ==========================================
-- 2. DYNAMIC BANNERS TABLE SETUP (16:9)
-- ==========================================

-- Create Banners Table
CREATE TABLE IF NOT EXISTS banners (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  image_url TEXT NOT NULL,
  title TEXT,
  banner_type TEXT DEFAULT 'image', -- 'image' or 'video'
  order_index INTEGER DEFAULT 0,
  storage_path TEXT, -- Used for deleting files from storage
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row Level Security (RLS)
ALTER TABLE banners ENABLE ROW LEVEL SECURITY;

-- Policy: Allow everyone to view banners
DROP POLICY IF EXISTS "Banners are viewable by everyone" ON banners;
CREATE POLICY "Banners are viewable by everyone" ON banners 
FOR SELECT USING (true);

-- Policy: Allow only Admins to manage banners
DROP POLICY IF EXISTS "Admins can manage banners" ON banners;
CREATE POLICY "Admins can manage banners" ON banners 
FOR ALL TO authenticated 
USING (public.is_admin()) 
WITH CHECK (public.is_admin());


-- ==========================================
-- 3. STORAGE POLICIES (Supabase Storage)
-- ==========================================
-- **IMPORTANT**: Manually create a bucket named 'banners' (lowercase) in Supabase Storage.

-- Policy: Allow public read access to 'banners' bucket
DROP POLICY IF EXISTS "Public Access Banners" ON storage.objects;
CREATE POLICY "Public Access Banners" ON storage.objects 
FOR SELECT USING (bucket_id = 'banners');

-- Policy: Allow Admins to upload/update/delete files in 'banners' bucket
DROP POLICY IF EXISTS "Admins Manage Banners Storage" ON storage.objects;
CREATE POLICY "Admins Manage Banners Storage" ON storage.objects 
FOR ALL TO authenticated 
USING (
  bucket_id = 'banners' 
  AND (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
)
WITH CHECK (
  bucket_id = 'banners' 
  AND (SELECT is_admin FROM public.profiles WHERE id = auth.uid()) = true
);
