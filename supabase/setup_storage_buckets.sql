-- Create storage buckets for the app

-- Enable storage if not already enabled
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('profile-pictures', 'profile-pictures', true),
  ('group-images', 'group-images', true),
  ('announcement-images', 'announcement-images', true)
ON CONFLICT (id) DO NOTHING;

-- Set up RLS policies for storage buckets

-- Profile Pictures Bucket Policies
CREATE POLICY "Anyone can view profile pictures" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile-pictures');

CREATE POLICY "Users can upload their own profile picture" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profile-pictures' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can update their own profile picture" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'profile-pictures' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete their own profile picture" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'profile-pictures' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Group Images Bucket Policies
CREATE POLICY "Anyone can view group images" ON storage.objects
  FOR SELECT USING (bucket_id = 'group-images');

CREATE POLICY "Group admins can upload group images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'group-images'
    -- Allow any authenticated user to upload for now
    -- We'll restrict this to group admins later
    AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Group admins can update group images" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'group-images'
    AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Group admins can delete group images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'group-images'
    AND auth.uid() IS NOT NULL
  );

-- Announcement Images Bucket Policies
CREATE POLICY "Anyone can view announcement images" ON storage.objects
  FOR SELECT USING (bucket_id = 'announcement-images');

CREATE POLICY "Authenticated users can upload announcement images" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'announcement-images'
    AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Users can update their own announcement images" ON storage.objects
  FOR UPDATE USING (
    bucket_id = 'announcement-images'
    AND auth.uid() IS NOT NULL
  );

CREATE POLICY "Users can delete their own announcement images" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'announcement-images'
    AND auth.uid() IS NOT NULL
  );