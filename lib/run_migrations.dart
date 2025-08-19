import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://enukwrgrbbglxvllcjjn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzNDkxMzAsImV4cCI6MjA0ODkyNTEzMH0.1A5VqPQQnMQSvI-U25Y8yQ9y7OzVBkR6KT0jKYLpFa8',
  );

  final client = Supabase.instance.client;
  
  print('Checking database schema...\n');
  
  // Check groups table
  try {
    print('Checking groups table...');
    final result = await client
        .from('groups')
        .select('id, name, city, teacher_title, teacher_full_name, capoeira_style')
        .limit(1);
    print('✅ Groups table has all required columns');
  } catch (e) {
    print('❌ Groups table missing columns: $e');
    print('\nPlease run this SQL in Supabase Dashboard:');
    print('''
ALTER TABLE groups 
ADD COLUMN IF NOT EXISTS city TEXT DEFAULT 'Unknown City',
ADD COLUMN IF NOT EXISTS teacher_title TEXT DEFAULT 'Professor',
ADD COLUMN IF NOT EXISTS teacher_full_name TEXT DEFAULT 'Unknown Teacher',
ADD COLUMN IF NOT EXISTS capoeira_style TEXT DEFAULT 'contemporanea',
ADD COLUMN IF NOT EXISTS lineage TEXT,
ADD COLUMN IF NOT EXISTS header_image_url TEXT,
ADD COLUMN IF NOT EXISTS teacher_profile_picture TEXT,
ADD COLUMN IF NOT EXISTS admin_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS teacher_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS member_ids TEXT[] DEFAULT '{}';
    ''');
  }
  
  // Check users table
  try {
    print('\nChecking users table...');
    final result = await client
        .from('users')
        .select('id, teaching_group_ids, joined_group_ids')
        .limit(1);
    print('✅ Users table has all required columns');
  } catch (e) {
    print('❌ Users table missing columns: $e');
    print('\nPlease run this SQL in Supabase Dashboard:');
    print('''
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS teaching_group_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS joined_group_ids TEXT[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS affiliation_group_id TEXT,
ADD COLUMN IF NOT EXISTS group_id TEXT,
ADD COLUMN IF NOT EXISTS group_name TEXT,
ADD COLUMN IF NOT EXISTS teacher_name TEXT;
    ''');
  }
  
  // Check storage buckets
  try {
    print('\nChecking storage buckets...');
    final buckets = await client.storage.listBuckets();
    final requiredBuckets = ['profile-pictures', 'group-images', 'announcement-images'];
    
    for (final bucket in requiredBuckets) {
      if (buckets.any((b) => b.id == bucket)) {
        print('✅ Storage bucket exists: $bucket');
      } else {
        print('❌ Storage bucket missing: $bucket');
      }
    }
    
    if (!buckets.any((b) => requiredBuckets.contains(b.id))) {
      print('\nPlease run this SQL in Supabase Dashboard:');
      print('''
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('profile-pictures', 'profile-pictures', true),
  ('group-images', 'group-images', true),
  ('announcement-images', 'announcement-images', true)
ON CONFLICT (id) DO NOTHING;
      ''');
    }
  } catch (e) {
    print('❌ Could not check storage buckets: $e');
  }
  
  print('\n========================================');
  print('Migration check complete!');
  print('If you see any ❌ above, please run the provided SQL in your Supabase Dashboard.');
  print('Dashboard URL: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/sql');
}