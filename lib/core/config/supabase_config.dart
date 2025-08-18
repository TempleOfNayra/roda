import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://enukwrgrbbglxvllcjjn.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NzQ5NTMsImV4cCI6MjA3MTA1MDk1M30.W6sz8lohUh0wa1lsxQsGEKe2JqVHiQtrdswcoKakbUQ';
  
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      storageOptions: const StorageClientOptions(
        retryAttempts: 3,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 2,
      ),
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => client.auth;
  static SupabaseStorageClient get storage => client.storage;
}