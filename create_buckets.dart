// COMMENTED OUT - Script for creating Supabase storage buckets
// Keeping for reference but not needed in production

/*
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://enukwrgrbbglxvllcjjn.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  );

  try {
    print('Creating storage buckets...');
    
    // Create profile-pictures bucket
    await supabase.storage.createBucket(
      'profile-pictures',
      BucketOptions(public: true),
    );
    print('✅ Created profile-pictures bucket');
  } catch (e) {
    print('❌ Error creating profile-pictures bucket: $e');
  }

  print('\nBucket creation complete!');
}
*/