-- Create storage buckets for the app
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('profile-pictures', 'profile-pictures', true),
  ('group-images', 'group-images', true),
  ('announcement-images', 'announcement-images', true)
ON CONFLICT (id) DO NOTHING;
