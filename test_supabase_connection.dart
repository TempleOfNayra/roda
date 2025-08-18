import 'package:roda/core/config/supabase_config.dart';

void main() async {
  print('Testing Supabase connection...');
  
  try {
    await SupabaseConfig.initialize();
    print('✅ Supabase initialized successfully!');
    
    // Test if tables exist
    print('\nChecking if schema is applied...');
    
    try {
      final groups = await SupabaseConfig.client
          .from('groups')
          .select()
          .limit(1);
      print('✅ Groups table exists');
    } catch (e) {
      print('❌ Groups table not found - need to run schema');
      print('Error: $e');
    }
    
    try {
      final users = await SupabaseConfig.client
          .from('users')
          .select()
          .limit(1);
      print('✅ Users table exists');
    } catch (e) {
      print('❌ Users table not found - need to run schema');
    }
    
    try {
      final schedules = await SupabaseConfig.client
          .from('schedules')
          .select()
          .limit(1);
      print('✅ Schedules table exists');
    } catch (e) {
      print('❌ Schedules table not found - need to run schema');
    }
    
    print('\nConnection test complete!');
    
  } catch (e) {
    print('❌ Failed to initialize Supabase');
    print('Error: $e');
  }
}