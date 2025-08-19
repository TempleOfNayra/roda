import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://enukwrgrbbglxvllcjjn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVudWt3cmdyYmJnbHh2bGxjampuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzNDk1MzIsImV4cCI6MjA0ODkyNTUzMn0.HhKrYXN8W9v8F7TIvsxiJPQ3s6x6bYBXpLlHwYhWyEo',
  );
  
  final client = Supabase.instance.client;
  
  try {
    print('Testing map_classes view access...');
    
    // Try to query the view
    final response = await client
        .from('map_classes')
        .select('id, scheduled_date, location_name')
        .limit(5);
    
    print('Success! Found ${response.length} classes');
    for (var item in response) {
      print('  - ${item['scheduled_date']}: ${item['location_name']}');
    }
  } catch (e) {
    print('Error: $e');
  }
  
  // Also test the simpler query the app is using
  try {
    print('\nTesting full map query...');
    final response = await client
        .from('map_classes')
        .select('*')
        .gte('scheduled_date', DateTime.now().toIso8601String().split('T')[0])
        .lte('scheduled_date', DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0])
        .order('scheduled_date', ascending: true)
        .limit(100);
    
    print('Full query success! Found ${response.length} classes');
  } catch (e) {
    print('Full query error: $e');
  }
}