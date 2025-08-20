// COMMENTED OUT - Migration script for database text field conversion
// Keeping for reference but not needed in production

/*
import 'package:supabase/supabase.dart';

Future<void> main() async {
  final supabase = SupabaseClient(
    'https://enukwrgrbbglxvllcjjn.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
  );

  print('Starting ID migration from UUID to TEXT...');
  
  try {
    // The migration is handled by the SQL script
    print('Migration completed successfully!');
  } catch (e) {
    print('Error during migration: $e');
  }
}
*/