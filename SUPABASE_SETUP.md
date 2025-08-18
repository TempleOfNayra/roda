# Supabase Setup Instructions

## 1. Create Supabase Project

1. Go to [https://supabase.com](https://supabase.com)
2. Sign up or login
3. Click "New Project"
4. Fill in:
   - Project name: `roda-app` (or your preference)
   - Database Password: (save this securely)
   - Region: Choose closest to your users
   - Plan: Free tier

## 2. Apply Database Schema

1. In Supabase Dashboard, go to **SQL Editor**
2. Click "New Query"
3. Copy the entire contents of `supabase/schema.sql`
4. Paste and click "Run"

## 3. Configure Authentication

1. Go to **Authentication** → **Providers**
2. Enable:
   - Email (already enabled by default)
   - Apple (for iOS sign-in)
   - Google (optional)

### For Apple Sign-In:
- Add your Apple Services ID
- Add your Apple Team ID
- Upload your Apple Sign-In Key

### For Google Sign-In:
- Add your Google Client ID
- Add your Google Client Secret

## 4. Get Your API Keys

1. Go to **Settings** → **API**
2. Copy:
   - Project URL → paste in `supabase_config.dart`
   - Anon/Public Key → paste in `supabase_config.dart`

## 5. Configure Storage Buckets

Run this in SQL Editor:

```sql
-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES 
  ('profile-pictures', 'profile-pictures', true),
  ('group-headers', 'group-headers', true);

-- Allow authenticated users to upload their profile picture
CREATE POLICY "Users can upload own profile picture" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'profile-pictures' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Allow public read access to profile pictures
CREATE POLICY "Profile pictures are public" ON storage.objects
  FOR SELECT USING (bucket_id = 'profile-pictures');

-- Allow group admins to upload group headers
CREATE POLICY "Admins can upload group headers" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'group-headers' AND
    EXISTS (
      SELECT 1 FROM group_members
      WHERE group_id = (storage.foldername(name))[1]::uuid
        AND user_id = auth.uid()
        AND role = 'admin'
    )
  );

-- Allow public read access to group headers
CREATE POLICY "Group headers are public" ON storage.objects
  FOR SELECT USING (bucket_id = 'group-headers');
```

## 6. Enable PostGIS (Already done in schema)

PostGIS is automatically enabled in the schema file with:
```sql
CREATE EXTENSION IF NOT EXISTS "postgis";
```

## 7. Configure Realtime

1. Go to **Database** → **Replication**
2. Enable replication for these tables:
   - `class_instances` (for map updates)
   - `class_attendance` (for live attendance)
   - `announcements` (for group announcements)

## 8. Update Flutter App

In `lib/core/config/supabase_config.dart`:

```dart
static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
static const String supabaseAnonKey = 'YOUR_ANON_KEY';
```

## 9. Test Connection

Run this test file to verify setup:

```dart
// test/supabase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:roda/core/config/supabase_config.dart';

void main() {
  test('Supabase connection', () async {
    await SupabaseConfig.initialize();
    
    final response = await SupabaseConfig.client
        .from('groups')
        .select()
        .limit(1);
    
    print('Connection successful!');
    print('Response: $response');
  });
}
```

## 10. Migration Script (Optional)

If you have existing data in Firestore, we'll create a migration script later.

## Environment Variables (Recommended)

Create `.env` file:
```
SUPABASE_URL=https://YOUR_PROJECT.supabase.co
SUPABASE_ANON_KEY=your_anon_key
```

Add to `.gitignore`:
```
.env
```

Use flutter_dotenv package:
```dart
await dotenv.load();
static String supabaseUrl = dotenv.env['SUPABASE_URL']!;
static String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;
```