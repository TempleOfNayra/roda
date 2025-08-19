import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://enukwrgrbbglxvllcjjn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzNDkxMzAsImV4cCI6MjA0ODkyNTEzMH0.1A5VqPQQnMQSvI-U25Y8yQ9y7OzVBkR6KT0jKYLpFa8',
  );

  final client = Supabase.instance.client;
  
  try {
    // Check if buckets exist
    final buckets = await client.storage.listBuckets();
    print('Existing buckets: ${buckets.map((b) => b.id).toList()}');
    
    // Create buckets if they don't exist
    final requiredBuckets = ['profile-pictures', 'group-images', 'announcement-images'];
    
    for (final bucketId in requiredBuckets) {
      if (!buckets.any((b) => b.id == bucketId)) {
        try {
          await client.storage.createBucket(bucketId, BucketOptions(public: true));
          print('Created bucket: $bucketId');
        } catch (e) {
          print('Error creating bucket $bucketId: $e');
        }
      } else {
        print('Bucket already exists: $bucketId');
      }
    }
    
    print('Storage buckets setup complete!');
  } catch (e) {
    print('Error: $e');
  }
}