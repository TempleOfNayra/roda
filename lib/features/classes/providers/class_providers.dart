import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/class_session_model.dart';
import 'package:roda/features/classes/repositories/class_repository.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

final classRepositoryProvider = Provider<ClassRepository>((ref) {
  return ClassRepository(FirebaseFirestore.instance);
});

final classServiceProvider = Provider<ClassService>((ref) {
  return ClassService(ref);
});

final nextClassProvider = StreamProvider.family<ClassSessionModel?, String>((ref, groupId) {
  if (groupId.isEmpty) return Stream.value(null);
  
  final classRepository = ref.watch(classRepositoryProvider);
  return classRepository.getNextClassForGroup(groupId);
});

final upcomingClassesProvider = StreamProvider.family<List<ClassSessionModel>, String>((ref, groupId) {
  if (groupId.isEmpty) return Stream.value([]);
  
  final classRepository = ref.watch(classRepositoryProvider);
  return classRepository.getUpcomingClassesForGroup(groupId);
});

final teacherUpcomingClassesProvider = StreamProvider.family<List<ClassSessionModel>, String>((ref, teacherId) {
  print('teacherUpcomingClassesProvider called with teacherId: $teacherId');
  if (teacherId.isEmpty) {
    print('teacherId is empty, returning empty list');
    return Stream.value([]);
  }
  
  final classRepository = ref.watch(classRepositoryProvider);
  return classRepository.getUpcomingClassesForTeacher(teacherId);
});

// Provider to get existing recurring schedules for editing
final teacherRecurringSchedulesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return [];
  
  final now = DateTime.now();
  final endDate = now.add(const Duration(days: 30));
  
  print('Fetching recurring schedules for teacher: ${currentUser.id}');
  print('Date range: $now to $endDate');
  
  // First check if there are ANY classes for this teacher
  final allClassesSnapshot = await FirebaseFirestore.instance
      .collection('classes')
      .where('teacherId', isEqualTo: currentUser.id)
      .limit(5)
      .get();
  
  print('Total classes for teacher: ${allClassesSnapshot.docs.length}');
  if (allClassesSnapshot.docs.isNotEmpty) {
    print('Sample class data: ${allClassesSnapshot.docs.first.data()}');
  }
  
  // Get upcoming recurring classes - simplified query to avoid index requirement
  final classesSnapshot = await FirebaseFirestore.instance
      .collection('classes')
      .where('teacherId', isEqualTo: currentUser.id)
      .get();
  
  print('Found ${classesSnapshot.docs.length} total classes for teacher');
  
  // Filter in memory for recurring classes in date range
  final filteredDocs = classesSnapshot.docs.where((doc) {
    final data = doc.data();
    final scheduledDate = (data['scheduledDate'] as Timestamp).toDate();
    final recurrenceType = data['recurrenceType'] as String?;
    
    // Check if in date range
    if (scheduledDate.isBefore(now) || scheduledDate.isAfter(endDate)) {
      return false;
    }
    
    // Check if recurring
    if (recurrenceType != RecurrenceType.weekly.name && 
        recurrenceType != RecurrenceType.monthly.name) {
      return false;
    }
    
    return true;
  }).toList();
  
  print('Filtered to ${filteredDocs.length} recurring classes in date range');
  
  // Group by day of week and time to find unique patterns
  final patterns = <String, Map<String, dynamic>>{};
  
  for (final doc in filteredDocs) {
    final data = doc.data();
    final date = (data['scheduledDate'] as Timestamp).toDate();
    final dayOfWeek = date.weekday;
    final startTime = data['startTime'] as String;
    final endTime = data['endTime'] as String;
    final location = data['location'] as String;
    
    final key = '$dayOfWeek-$startTime-$endTime';
    
    if (!patterns.containsKey(key)) {
      patterns[key] = {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'location': location,
        'recurrenceType': data['recurrenceType'],
        'eventType': data['eventType'],
        'groupId': data['groupId'],
        'existingPattern': true,
      };
    }
  }
  
  print('Returning ${patterns.length} unique patterns: ${patterns.keys.toList()}');
  return patterns.values.toList();
});

class ClassService {
  final Ref _ref;
  
  ClassService(this._ref);
  
  ClassRepository get _classRepository => _ref.read(classRepositoryProvider);
  
  Future<void> markAttending(String classId, String userId) async {
    try {
      await _classRepository.addAttendingStudent(classId, userId);
    } catch (e) {
      throw Exception('Failed to mark attending: $e');
    }
  }
  
  Future<void> removeAttending(String classId, String userId) async {
    try {
      await _classRepository.removeAttendingStudent(classId, userId);
    } catch (e) {
      throw Exception('Failed to remove attending: $e');
    }
  }
  
  Future<void> markPresent(String classId, String userId) async {
    try {
      await _classRepository.markStudentPresent(classId, userId);
    } catch (e) {
      throw Exception('Failed to mark present: $e');
    }
  }
  
  Future<void> createRecurringClasses({
    required String groupId,
    required String groupName,
    required String teacherId,
    required List<Map<String, dynamic>> schedule,
    required int weeksAhead,
  }) async {
    try {
      final now = DateTime.now();
      final classes = <ClassSessionModel>[];
      
      for (int week = 0; week < weeksAhead; week++) {
        for (final daySchedule in schedule) {
          final dayOfWeek = daySchedule['dayOfWeek'] as int;
          final startTime = daySchedule['startTime'] as String;
          final endTime = daySchedule['endTime'] as String;
          
          // Calculate the date for this class
          final daysUntilClass = (dayOfWeek - now.weekday + 7) % 7 + (week * 7);
          final classDate = now.add(Duration(days: daysUntilClass));
          
          classes.add(ClassSessionModel(
            id: '',
            groupId: groupId,
            groupName: groupName,
            teacherId: teacherId,
            eventType: EventType.class_,
            scheduledDate: DateTime(
              classDate.year,
              classDate.month,
              classDate.day,
            ),
            startTime: startTime,
            endTime: endTime,
            location: daySchedule['location'] ?? '',
            latitude: daySchedule['latitude']?.toDouble(),
            longitude: daySchedule['longitude']?.toDouble(),
            recurrenceType: RecurrenceType.weekly,
            attendingStudentIds: [],
            presentStudentIds: [],
            status: ClassStatus.scheduled,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ));
        }
      }
      
      // Batch create all classes
      for (final classSession in classes) {
        await _classRepository.createClass(classSession);
      }
    } catch (e) {
      throw Exception('Failed to create recurring classes: $e');
    }
  }
  
  Future<void> updateFutureClasses({
    required int dayOfWeek,
    required String oldStartTime,
    required String oldEndTime,
    required String newStartTime,
    required String newEndTime,
    required String newLocation,
    required DateTime fromDate,
  }) async {
    try {
      final currentUser = await _ref.read(currentUserProvider.future);
      if (currentUser == null) throw Exception('User not found');
      
      // Get all future classes matching the old pattern
      final query = await FirebaseFirestore.instance
          .collection('classes')
          .where('teacherId', isEqualTo: currentUser.id)
          .where('startTime', isEqualTo: oldStartTime)
          .where('endTime', isEqualTo: oldEndTime)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(fromDate))
          .get();
      
      // Filter by day of week and update
      final batch = FirebaseFirestore.instance.batch();
      int updateCount = 0;
      
      for (final doc in query.docs) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        if (date.weekday == dayOfWeek) {
          batch.update(doc.reference, {
            'startTime': newStartTime,
            'endTime': newEndTime,
            'location': newLocation,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          updateCount++;
        }
      }
      
      if (updateCount > 0) {
        await batch.commit();
        print('Updated $updateCount future classes');
      }
    } catch (e) {
      throw Exception('Failed to update future classes: $e');
    }
  }
}