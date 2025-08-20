// COMMENTED OUT - Script for creating storage buckets
// Keeping for reference but not needed in production

/*
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://enukwrgrbbglxvllcjjn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  );

  final client = Supabase.instance.client;

  try {
    print('Creating storage buckets...');
    
    // Create buckets
    await client.storage.createBucket(
      'profile-pictures',
      const BucketOptions(public: true),
    );
    print('Created profile-pictures bucket');
  } catch (e) {
    print('Error: $e');
  }

  print('Done!');
}
*/