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
    }
    
    try {
      final _ = await SupabaseConfig.client
          .from('users')
          .select()
          .limit(1);
    } catch (e) {
    }
    
    try {
      final _ = await SupabaseConfig.client
          .from('schedules')
          .select()
          .limit(1);
    } catch (e) {
    }
    
    
  } catch (e) {
  }
}