import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/core/models/class_instance.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

final supabaseClassServiceProvider = Provider((ref) => SupabaseClassService());

class SupabaseClassService {
  final _client = SupabaseConfig.client;
  
  // Get class instance by ID
  Future<ClassInstance?> getClassInstance(String instanceId) async {
    try {
      final response = await _client
          .from('class_instances')
          .select('''
            *,
            schedules!inner(
              id, name, description, event_type, 
              location, location_name, location_address,
              timezone, teacher_id, group_id, price, max_students
            )
          ''')
          .eq('id', instanceId)
          .maybeSingle();
      
      if (response == null) return null;
      
      return _mapToClassInstance(response);
    } catch (e) {
      throw Exception('Failed to get class instance: $e');
    }
  }
  
  // Get upcoming classes for a teacher
  Future<List<ClassInstance>> getTeacherUpcomingClasses(String teacherId) async {
    try {
      final response = await _client
          .from('class_instances')
          .select('''
            *,
            schedules!inner(
              id, name, description, event_type,
              location, location_name, location_address,
              timezone, teacher_id, group_id, price, max_students
            )
          ''')
          .eq('schedules.teacher_id', teacherId)
          .gte('scheduled_date', DateTime.now().toIso8601String().split('T')[0])
          .eq('is_cancelled', false)
          .order('scheduled_date')
          .limit(20);
      
      return response.map<ClassInstance>((data) => 
        _mapToClassInstance(data)
      ).toList();
    } catch (e) {
      throw Exception('Failed to get teacher classes: $e');
    }
  }
  
  // Get classes within a geographic area (for map)
  Future<List<ClassInstance>> getClassesNearLocation({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Use the map_classes view which combines schedule and instance data
      final response = await _client
          .from('map_classes')
          .select()
          .gte('scheduled_date', (startDate ?? DateTime.now()).toIso8601String().split('T')[0])
          .lte('scheduled_date', (endDate ?? DateTime.now().add(const Duration(days: 30))).toIso8601String().split('T')[0]);
      
      // Filter by distance in app for now (PostGIS geographic query would be better)
      // In production, use: .rpc('find_classes_near', params: {...})
      
      return response.map<ClassInstance>((data) => 
        _mapViewToClassInstance(data)
      ).toList();
    } catch (e) {
      throw Exception('Failed to get classes near location: $e');
    }
  }
  
  // Update class instance (for customizations)
  Future<void> updateClassInstance(String instanceId, {
    String? customName,
    String? customDescription,
    DateTime? customStartTime,
    DateTime? customEndTime,
    double? customPrice,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{};
      
      if (customName != null) updates['custom_name'] = customName;
      if (customDescription != null) updates['custom_description'] = customDescription;
      if (customStartTime != null) {
        updates['custom_start_time'] = 
          '${customStartTime.hour.toString().padLeft(2, '0')}:${customStartTime.minute.toString().padLeft(2, '0')}';
      }
      if (customEndTime != null) {
        updates['custom_end_time'] = 
          '${customEndTime.hour.toString().padLeft(2, '0')}:${customEndTime.minute.toString().padLeft(2, '0')}';
      }
      if (customPrice != null) updates['custom_price'] = customPrice;
      if (notes != null) updates['notes'] = notes;
      
      await _client
          .from('class_instances')
          .update(updates)
          .eq('id', instanceId);
    } catch (e) {
      throw Exception('Failed to update class instance: $e');
    }
  }
  
  // Cancel class instance
  Future<void> cancelClassInstance(String instanceId, String reason) async {
    try {
      await _client
          .from('class_instances')
          .update({
            'is_cancelled': true,
            'cancellation_reason': reason,
          })
          .eq('id', instanceId);
      
      // TODO: Notify registered students
    } catch (e) {
      throw Exception('Failed to cancel class: $e');
    }
  }
  
  // Register for a class
  Future<void> registerForClass(String instanceId, String userId) async {
    try {
      await _client
          .from('class_attendance')
          .upsert({
            'class_instance_id': instanceId,
            'user_id': userId,
            'status': 'registered',
            'payment_status': 'pending',
          });
    } catch (e) {
      throw Exception('Failed to register for class: $e');
    }
  }
  
  // Unregister from a class
  Future<void> unregisterFromClass(String instanceId, String userId) async {
    try {
      await _client
          .from('class_attendance')
          .delete()
          .eq('class_instance_id', instanceId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to unregister from class: $e');
    }
  }
  
  // Mark attendance
  Future<void> markAttendance(String instanceId, String userId, bool present) async {
    try {
      await _client
          .from('class_attendance')
          .update({
            'status': present ? 'attended' : 'absent',
            'attended_at': present ? DateTime.now().toIso8601String() : null,
          })
          .eq('class_instance_id', instanceId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to mark attendance: $e');
    }
  }
  
  // Get attendance for a class
  Future<List<Map<String, dynamic>>> getClassAttendance(String instanceId) async {
    try {
      final response = await _client
          .from('class_attendance')
          .select('''
            *,
            users!inner(id, full_name, capoeira_name, email)
          ''')
          .eq('class_instance_id', instanceId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to get class attendance: $e');
    }
  }
  
  // Helper to map database response to ClassInstance
  ClassInstance _mapToClassInstance(Map<String, dynamic> data) {
    // final schedule = data['schedules'] as Map<String, dynamic>; // Used in commented code below
    
    // Parse times - commented out as values aren't used
    // final startTimeParts = (data['custom_start_time'] ?? schedule['start_time'] as String).split(':');
    // final endTimeParts = (data['custom_end_time'] ?? schedule['end_time'] as String).split(':');
    
    final scheduledDate = DateTime.parse(data['scheduled_date']);
    // Unused - commenting out to avoid lint warnings
    // final startTime = DateTime(
    //   scheduledDate.year, scheduledDate.month, scheduledDate.day,
    //   int.parse(startTimeParts[0]), int.parse(startTimeParts[1]),
    // );
    // final endTime = DateTime(
    //   scheduledDate.year, scheduledDate.month, scheduledDate.day,
    //   int.parse(endTimeParts[0]), int.parse(endTimeParts[1]),
    // );
    
    // Parse location - commented out as values aren't used
    // double? latitude, longitude;
    // final location = data['custom_location'] ?? schedule['location'];
    // if (location != null) {
    //   final pointStr = location as String;
    //   final matches = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)').firstMatch(pointStr);
    //   if (matches != null) {
    //     longitude = double.parse(matches.group(1)!);
    //     latitude = double.parse(matches.group(2)!);
    //   }
    // }
    
    return ClassInstance(
      id: data['id'],
      templateId: data['schedule_id'],
      scheduledDate: scheduledDate,
      status: ClassStatus.scheduled,
      attendingStudentIds: List<String>.from(data['attending_student_ids'] ?? []),
      presentStudentIds: List<String>.from(data['present_student_ids'] ?? []),
      paymentConfirmations: {},
      notes: data['notes'],
    );
  }
  
  // Helper to map view response to ClassInstance (from map_classes view)
  ClassInstance _mapViewToClassInstance(Map<String, dynamic> data) {
    // Parse location - commented out as values aren't used
    // double? latitude, longitude;
    // if (data['location'] != null) {
    //   final pointStr = data['location'] as String;
    //   final matches = RegExp(r'POINT\(([-\d.]+) ([-\d.]+)\)').firstMatch(pointStr);
    //   if (matches != null) {
    //     longitude = double.parse(matches.group(1)!);
    //     latitude = double.parse(matches.group(2)!);
    //   }
    // }
    
    final scheduledDate = DateTime.parse(data['scheduled_date']);
    // final startUtc = DateTime.parse(data['start_datetime_utc']); // Unused
    
    return ClassInstance(
      id: data['id'],
      templateId: data['schedule_id'] ?? '',
      scheduledDate: scheduledDate,
      status: data['is_cancelled'] ? ClassStatus.cancelled : ClassStatus.scheduled,
      attendingStudentIds: List<String>.from(data['attending_student_ids'] ?? []),
      presentStudentIds: List<String>.from(data['present_student_ids'] ?? []),
      paymentConfirmations: {},
      notes: data['notes'],
    );
  }
}

// Unused providers - removed by DCM
// // Provider for upcoming classes (for map and lists)
// final upcomingClassesProvider = FutureProvider<List<ClassInstance>>((ref) async {
//   final service = ref.watch(supabaseClassServiceProvider);
//   
//   // Get classes for next 30 days
//   // In production, this would use location from user
//   return service.getClassesNearLocation(
//     latitude: 37.7749, // Default to SF
//     longitude: -122.4194,
//     radiusMeters: 50000, // 50km
//   );
// });

// // Provider for teacher's upcoming classes
// final teacherUpcomingClassesProvider = FutureProvider<List<ClassInstance>>((ref) async {
//   final currentUser = ref.watch(currentUserProvider).value;
//   if (currentUser == null) return [];
//   
//   final service = ref.watch(supabaseClassServiceProvider);
//   return service.getTeacherUpcomingClasses(currentUser.id);
// });

// // Provider for class attendance
// final classAttendanceProvider = FutureProvider.family<List<Map<String, dynamic>>, String>(
//   (ref, classId) async {
//     final service = ref.watch(supabaseClassServiceProvider);
//     return service.getClassAttendance(classId);
//   },
// );