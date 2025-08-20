import 'package:roda/core/config/supabase_config.dart';

void main() async {
  
  try {
    await SupabaseConfig.initialize();
    
    // Test if tables exist
    
    try {
      final _ = await SupabaseConfig.client
          .from('groups')
          .select()
          .limit(1);
    } catch (e) {
      // Table might not exist
    }
    
    try {
      final _ = await SupabaseConfig.client
          .from('users')
          .select()
          .limit(1);
    } catch (e) {
      // Table might not exist
    }
    
    try {
      final _ = await SupabaseConfig.client
          .from('schedules')
          .select()
          .limit(1);
    } catch (e) {
      // Table might not exist
    }
    
    
  } catch (e) {
    // Connection failed
  }
}