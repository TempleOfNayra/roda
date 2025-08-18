import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://enukwrgrbbglxvllcjjn.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU0NzQ5NTMsImV4cCI6MjA3MTA1MDk1M30.W6sz8lohUh0wa1lsxQsGEKe2JqVHiQtrdswcoKakbUQ',
  );

  print('Connected to Supabase');
  
  // Note: DDL operations like ALTER TABLE cannot be run through the client API
  // You need to run these in the Supabase SQL Editor in the dashboard
  
  print('''
To change IDs from UUID to TEXT, run this in your Supabase SQL Editor:

1. Go to: https://supabase.com/dashboard/project/enukwrgrbbglxvllcjjn/sql/new
2. Copy and paste the migration SQL from: supabase/migrations/20240101000003_change_ids_to_text.sql
3. Click "Run"
  ''');
}