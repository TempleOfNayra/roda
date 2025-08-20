import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/core/utils/logger.dart';

final supabaseScheduleServiceProvider = Provider((ref) => SupabaseScheduleService());

class SupabaseScheduleService {
  final _client = SupabaseConfig.client;
  
  // Create a new schedule template
  Future<String> createSchedule({
    required String groupId,
    required String teacherId,
    required String name,
    String? description,
    required String eventType,
    required double latitude,
    required double longitude,
    required String locationName,
    String? locationAddress,
    required String timezone,
    required int dayOfWeek,
    required DateTime startTime,
    required DateTime endTime,
    double? price,
    int? maxStudents,
  }) async {
    try {
      Logger.debug('[SupabaseScheduleService] Creating schedule for group: $groupId');
      Logger.debug('[SupabaseScheduleService] Location: $locationName at ($latitude, $longitude)');
      Logger.debug('[SupabaseScheduleService] Day: $dayOfWeek, Time: ${startTime.hour}:${startTime.minute} - ${endTime.hour}:${endTime.minute}');
      
      // Create PostGIS point for location
      final point = 'POINT($longitude $latitude)';
      
      final insertData = {
        'group_id': groupId,
        'teacher_id': teacherId,
        'name': name,
        'description': description,
        'event_type': eventType,
        'location': point,
        'location_name': locationName,
        'location_address': locationAddress,
        'timezone': timezone,
        'day_of_week': dayOfWeek,
        'start_time': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
        'end_time': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
        'price': price,
        'max_students': maxStudents,
        'is_active': true,
      };
      
      Logger.debug('[SupabaseScheduleService] Inserting schedule with data: $insertData');
      
      final response = await _client
          .from('schedules')
          .insert(insertData)
          .select()
          .single();
      
      Logger.debug('[SupabaseScheduleService] Schedule created with ID: ${response['id']}');
      final scheduleId = response['id'];
      
      // Generate initial class instances (next 4 months = 16 weeks)
      Logger.debug('[SupabaseScheduleService] Generating class instances...');
      await generateClassInstances(
        scheduleId: scheduleId,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 16 * 7)), // 4 months
      );
      
      Logger.debug('[SupabaseScheduleService] Successfully created schedule and instances');
      return scheduleId;
    } catch (e, stackTrace) {
      Logger.debug('[SupabaseScheduleService] Error creating schedule: $e');
      Logger.debug('[SupabaseScheduleService] Stack trace: $stackTrace');
      throw Exception('Failed to create schedule: $e');
    }
  }
  
  // Generate class instances for a schedule
  Future<void> generateClassInstances({
    required String scheduleId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      Logger.debug('[SupabaseScheduleService] Calling generate_class_instances RPC');
      Logger.debug('[SupabaseScheduleService] Parameters: schedule_id=$scheduleId, start=${startDate.toIso8601String().split('T')[0]}, end=${endDate.toIso8601String().split('T')[0]}');
      
      // Call the database function to generate instances
      await _client.rpc('generate_class_instances', params: {
        'p_schedule_id': scheduleId, // Text ID, not UUID
        'p_start_date': startDate.toIso8601String().split('T')[0],
        'p_end_date': endDate.toIso8601String().split('T')[0],
      });
      
      Logger.debug('[SupabaseScheduleService] Successfully generated class instances');
    } catch (e, stackTrace) {
      Logger.debug('[SupabaseScheduleService] Error generating instances: $e');
      Logger.debug('[SupabaseScheduleService] Stack trace: $stackTrace');
      throw Exception('Failed to generate class instances: $e');
    }
  }
  
  // Get schedules for a teacher
  Future<List<ScheduleTemplate>> getTeacherSchedules(String teacherId) async {
    try {
      final response = await _client
          .from('schedules')
          .select()
          .eq('teacher_id', teacherId)
          .eq('is_active', true);
      
      return response.map<ScheduleTemplate>((data) => 
        _mapToScheduleTemplate(data)
      ).toList();
    } catch (e) {
      throw Exception('Failed to get teacher schedules: $e');
    }
  }
  
  // Get schedules for a group
  Future<List<ScheduleTemplate>> getGroupSchedules(String groupId) async {
    try {
      final response = await _client
          .from('schedules')
          .select()
          .eq('group_id', groupId)
          .eq('is_active', true);
      
      return response.map<ScheduleTemplate>((data) => 
        _mapToScheduleTemplate(data)
      ).toList();
    } catch (e) {
      throw Exception('Failed to get group schedules: $e');
    }
  }
  
  // Update schedule
  Future<void> updateSchedule(String scheduleId, Map<String, dynamic> updates) async {
    try {
      await _client
          .from('schedules')
          .update(updates)
          .eq('id', scheduleId);
      
      // If time or day changed, regenerate future instances
      if (updates.containsKey('day_of_week') || 
          updates.containsKey('start_time') || 
          updates.containsKey('end_time')) {
        await regenerateFutureInstances(scheduleId);
      }
    } catch (e) {
      throw Exception('Failed to update schedule: $e');
    }
  }
  
  // Delete (deactivate) schedule
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      await _client
          .from('schedules')
          .update({'is_active': false})
          .eq('id', scheduleId);
      
      // Cancel all future instances
      await _client
          .from('class_instances')
          .update({'is_cancelled': true})
          .eq('schedule_id', scheduleId)
          .gte('scheduled_date', DateTime.now().toIso8601String().split('T')[0]);
    } catch (e) {
      throw Exception('Failed to delete schedule: $e');
    }
  }
  
  // Regenerate future instances after schedule change
  Future<void> regenerateFutureInstances(String scheduleId) async {
    try {
      // Delete future unmodified instances
      await _client
          .from('class_instances')
          .delete()
          .eq('schedule_id', scheduleId)
          .gte('scheduled_date', DateTime.now().toIso8601String().split('T')[0])
          .isFilter('custom_name', null); // Only delete unmodified instances
      
      // Generate new instances (4 months)
      await generateClassInstances(
        scheduleId: scheduleId,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 16 * 7)), // 4 months
      );
    } catch (e) {
      throw Exception('Failed to regenerate instances: $e');
    }
  }
  
  // Helper to map database response to ScheduleTemplate
  ScheduleTemplate _mapToScheduleTemplate(Map<String, dynamic> data) {
    // Parse time strings
    final startTimeParts = (data['start_time'] as String).split(':');
    final endTimeParts = (data['end_time'] as String).split(':');
    
    
    // Parse location from PostGIS point
    // Format: POINT(longitude latitude)
    double? latitude, longitude;
    if (data['location'] != null) {
      final pointStr = data['location'] as String;
      final matches = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)').firstMatch(pointStr);
      if (matches != null) {
        longitude = double.parse(matches.group(1)!);
        latitude = double.parse(matches.group(2)!);
      }
    }
    
    // Parse event type
    EventType eventType;
    switch (data['event_type']) {
      case 'roda':
        eventType = EventType.roda;
      default:
        eventType = EventType.class_;
    }
    
    // Parse recurrence type
    RecurrenceType recurrenceType;
    switch (data['recurrence_type'] ?? 'weekly') {
      case 'daily':
        recurrenceType = RecurrenceType.daily;
      case 'weekly':
        recurrenceType = RecurrenceType.weekly;
      case 'biweekly':
        recurrenceType = RecurrenceType.biweekly;
      case 'monthly':
        recurrenceType = RecurrenceType.monthly;
      default:
        recurrenceType = RecurrenceType.weekly;
    }
    
    return ScheduleTemplate(
      id: data['id'],
      groupId: data['group_id'],
      teacherId: data['teacher_id'],
      teacherName: data['teacher_name'] ?? '',
      groupName: data['group_name'] ?? '',
      eventType: eventType,
      recurrenceType: recurrenceType,
      dayOfWeek: data['day_of_week'],
      startTime: startTimeParts.join(':'),
      endTime: endTimeParts.join(':'),
      location: data['location_address'] ?? '',
      latitude: latitude,
      longitude: longitude,
      price: data['price']?.toDouble(),
      createdAt: DateTime.parse(data['created_at']),
      isActive: data['is_active'] ?? true,
    );
  }
}

// Unused - removed by DCM
// // Provider for teacher's schedules
// final teacherSchedulesProvider = FutureProvider<List<ScheduleTemplate>>((ref) async {
//   final currentUser = ref.watch(currentUserProvider).value;
//   if (currentUser == null) return [];
//   
//   final service = ref.watch(supabaseScheduleServiceProvider);
//   return service.getTeacherSchedules(currentUser.id);
// });

// // Provider for group's schedules
// final groupSchedulesProvider = FutureProvider.family<List<ScheduleTemplate>, String>(
//   (ref, groupId) async {
//     final service = ref.watch(supabaseScheduleServiceProvider);
//     return service.getGroupSchedules(groupId);
//   },
// );

// Provider for user's registered classes
final userRegisteredClassesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
  (ref, userId) async {
    final response = await SupabaseConfig.client
        .from('class_instances')
        .select('''
          *,
          schedule:schedules(
            *,
            group:groups(*)
          )
        ''')
        .contains('attending_student_ids', [userId])
        .gte('scheduled_date', DateTime.now().toIso8601String())
        .order('scheduled_date');
    
    return List<Map<String, dynamic>>.from(response);
  },
);

// Unused - removed by DCM
// // Provider for group's class instances
// final groupClassInstancesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
//   (ref, groupId) async {
//     try {
//       final response = await SupabaseConfig.client
//           .from('class_instances')
//           .select('''
//             id,
//             schedule_id,
//             scheduled_date,
//             start_time,
//             end_time,
//             is_cancelled,
//             custom_name,
//             attending_student_ids,
//             present_student_ids,
//             schedules!inner (
//               name,
//               event_type,
//               location_name,
//               price,
//               group_id
//             )
//           ''')
//           .eq('schedules.group_id', groupId)
//           .gte('scheduled_date', DateTime.now().toIso8601String().split('T')[0])
//           .order('scheduled_date', ascending: true)
//           .limit(20);
//       
//       // Transform the response to flatten the schedule data
//       return (response as List).map((instance) {
//         final schedule = instance['schedules'];
//         return {
//           'id': instance['id'],
//           'schedule_id': instance['schedule_id'],
//           'scheduled_date': instance['scheduled_date'],
//           'start_time': instance['start_time'],
//           'end_time': instance['end_time'],
//           'is_cancelled': instance['is_cancelled'],
//           'name': instance['custom_name'] ?? schedule['name'],
//           'event_type': schedule['event_type'],
//           'location_name': schedule['location_name'],
//           'price': schedule['price'],
//           'attending_student_ids': instance['attending_student_ids'] ?? [],
//           'present_student_ids': instance['present_student_ids'] ?? [],
//         };
//       }).toList();
//     } catch (e) {
//       Logger.debug('Error fetching group class instances: $e');
//       return [];
//     }
//   },
// );