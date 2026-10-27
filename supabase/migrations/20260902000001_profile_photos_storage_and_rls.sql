-- ── Migration: 20260902000001_profile_photos_storage_and_rls.sql ──────────
-- Production Storage Bucket & Security Setup for Profile Photos

-- 1. Ensure storage bucket exists and is public
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile_photos',
  'profile_photos',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg'];

-- 2. Storage RLS Policies for profile_photos

-- Allow public read access to candidate photos
DROP POLICY IF EXISTS "Public view for profile photos" ON storage.objects;
CREATE POLICY "Public view for profile photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'profile_photos');

-- Allow authenticated users to upload ONLY into their own folder (folder name == auth.uid())
DROP POLICY IF EXISTS "Authenticated users can upload own profile photos" ON storage.objects;
CREATE POLICY "Authenticated users can upload own profile photos"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'profile_photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow authenticated users to update ONLY their own photos
DROP POLICY IF EXISTS "Authenticated users can update own profile photos" ON storage.objects;
CREATE POLICY "Authenticated users can update own profile photos"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'profile_photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow authenticated users to delete ONLY their own photos
DROP POLICY IF EXISTS "Authenticated users can delete own profile photos" ON storage.objects;
CREATE POLICY "Authenticated users can delete own profile photos"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'profile_photos' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- 3. Ensure profiles table has additional_photo_urls array column
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS additional_photo_urls TEXT[] DEFAULT '{}';
