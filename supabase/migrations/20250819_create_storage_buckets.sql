-- Create storage buckets for the application
-- This migration creates the necessary storage buckets with proper RLS policies

-- Create profile-pictures bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'profile-pictures',
  'profile-pictures', 
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

-- Create group-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'group-images',
  'group-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

-- Create announcement-images bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'announcement-images',
  'announcement-images',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

-- RLS Policies for profile-pictures bucket
CREATE POLICY "Public profiles are viewable by everyone"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'profile-pictures');

CREATE POLICY "Users can upload their own profile picture"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profile-pictures' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can update their own profile picture"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'profile-pictures' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own profile picture"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profile-pictures' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- RLS Policies for group-images bucket
CREATE POLICY "Public group images are viewable by everyone"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'group-images');

CREATE POLICY "Group admins and teachers can upload group images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'group-images' AND
  EXISTS (
    SELECT 1 FROM groups g
    WHERE g.id = (storage.foldername(name))[1]
    AND (
      auth.uid() = ANY(g.admin_ids) OR
      auth.uid() = ANY(g.teacher_ids)
    )
  )
);

CREATE POLICY "Group admins and teachers can update group images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'group-images' AND
  EXISTS (
    SELECT 1 FROM groups g
    WHERE g.id = (storage.foldername(name))[1]
    AND (
      auth.uid() = ANY(g.admin_ids) OR
      auth.uid() = ANY(g.teacher_ids)
    )
  )
);

CREATE POLICY "Group admins can delete group images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'group-images' AND
  EXISTS (
    SELECT 1 FROM groups g
    WHERE g.id = (storage.foldername(name))[1]
    AND auth.uid() = ANY(g.admin_ids)
  )
);

-- RLS Policies for announcement-images bucket
CREATE POLICY "Public announcement images are viewable by everyone"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'announcement-images');

CREATE POLICY "Group admins and teachers can upload announcement images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'announcement-images');

CREATE POLICY "Group admins and teachers can update announcement images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'announcement-images');

CREATE POLICY "Group admins and teachers can delete announcement images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'announcement-images');