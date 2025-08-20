import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/core/utils/logger.dart';

// Provider to fetch schedules for a specific group
final groupSchedulesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  try {
    final supabase = ref.read(supabaseClientProvider);
    
    Logger.debug('Fetching schedules for group: $groupId');
    
    // Fetch schedules for this group
    final response = await supabase
        .from('schedules')
        .select()
        .eq('group_id', groupId)
        .eq('is_active', true)
        .order('day_of_week', ascending: true)
        .order('start_time', ascending: true);
    
    Logger.debug('Found ${response.length} schedules for group $groupId');
    
    return List<Map<String, dynamic>>.from(response);
  } catch (e) {
    Logger.error('Failed to fetch group schedules', e);
    return [];
  }
});

// Format schedule for display
String formatScheduleTime(Map<String, dynamic> schedule) {
  final dayOfWeek = schedule['day_of_week'] as int?;
  final startTime = schedule['start_time'] as String?;
  final endTime = schedule['end_time'] as String?;
  
  if (dayOfWeek == null || startTime == null || endTime == null) {
    return '';
  }
  
  final days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final day = days[dayOfWeek];
  
  // Convert 24h to 12h format
  String format12Hour(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1];
    
    if (hour == 0) {
      return '12:${minute}am';
    } else if (hour < 12) {
      return '$hour:${minute}am';
    } else if (hour == 12) {
      return '12:${minute}pm';
    } else {
      return '${hour - 12}:${minute}pm';
    }
  }
  
  final start = format12Hour(startTime);
  final end = format12Hour(endTime);
  
  return '$day $start-$end';
}