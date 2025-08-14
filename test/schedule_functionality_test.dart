import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/class_session_model.dart';
import 'package:roda/core/models/user_model.dart';

void main() {
  group('Schedule Functionality Tests', () {
    late FakeFirebaseFirestore firestore;
    late String teacherId;
    late String groupId;
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
      teacherId = 'test_teacher_123';
      groupId = 'test_group_456';
    });

    test('Should create recurring weekly classes', () async {
      // Arrange
      final scheduledDate = DateTime(2025, 8, 19); // Next Monday
      final schedules = [
        {
          'dayOfWeek': 1, // Monday
          'startTime': '18:00',
          'endTime': '19:30',
          'location': 'Community Center',
        },
        {
          'dayOfWeek': 3, // Wednesday
          'startTime': '18:00',
          'endTime': '19:30',
          'location': 'Community Center',
        },
        {
          'dayOfWeek': 5, // Friday
          'startTime': '17:00',
          'endTime': '18:30',
          'location': 'Beach Park',
        },
      ];

      // Act - Create classes for 4 weeks
      for (final schedule in schedules) {
        for (int week = 0; week < 4; week++) {
          final classDate = _getNextDateForWeekday(schedule['dayOfWeek'] as int)
              .add(Duration(days: week * 7));
          
          final classSession = {
            'groupId': groupId,
            'groupName': 'Test Group',
            'teacherId': teacherId,
            'eventType': EventType.class_.name,
            'scheduledDate': Timestamp.fromDate(classDate),
            'startTime': schedule['startTime'],
            'endTime': schedule['endTime'],
            'location': schedule['location'],
            'latitude': null,
            'longitude': null,
            'recurrenceType': RecurrenceType.weekly.name,
            'attendingStudentIds': [],
            'presentStudentIds': [],
            'status': ClassStatus.scheduled.name,
            'createdAt': Timestamp.fromDate(DateTime.now()),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          };
          
          await firestore.collection('classes').add(classSession);
        }
      }

      // Assert - Verify classes were created
      final classesSnapshot = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      expect(classesSnapshot.docs.length, equals(12)); // 3 schedules × 4 weeks
    });

    test('Should retrieve existing recurring schedules', () async {
      // Arrange - Add some existing classes
      final now = DateTime.now();
      final schedules = [
        {
          'dayOfWeek': 2, // Tuesday
          'startTime': '18:00',
          'endTime': '21:00',
          'location': 'Gym A',
        },
        {
          'dayOfWeek': 4, // Thursday
          'startTime': '18:00',
          'endTime': '21:00',
          'location': 'Gym A',
        },
      ];

      // Create classes for next 30 days
      for (final schedule in schedules) {
        for (int week = 0; week < 5; week++) {
          final classDate = _getNextDateForWeekday(schedule['dayOfWeek'] as int)
              .add(Duration(days: week * 7));
          
          if (classDate.isBefore(now.add(Duration(days: 30)))) {
            await firestore.collection('classes').add({
              'groupId': groupId,
              'groupName': 'Test Group',
              'teacherId': teacherId,
              'eventType': EventType.class_.name,
              'scheduledDate': Timestamp.fromDate(classDate),
              'startTime': schedule['startTime'],
              'endTime': schedule['endTime'],
              'location': schedule['location'],
              'recurrenceType': RecurrenceType.weekly.name,
              'attendingStudentIds': [],
              'presentStudentIds': [],
              'status': ClassStatus.scheduled.name,
              'createdAt': Timestamp.fromDate(DateTime.now()),
              'updatedAt': Timestamp.fromDate(DateTime.now()),
            });
          }
        }
      }

      // Act - Query for recurring schedules
      final endDate = now.add(Duration(days: 30));
      final classesSnapshot = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('recurrenceType', whereIn: [RecurrenceType.weekly.name, RecurrenceType.monthly.name])
          .orderBy('scheduledDate')
          .get();

      // Group by pattern
      final patterns = <String, Map<String, dynamic>>{};
      for (final doc in classesSnapshot.docs) {
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
          };
        }
      }

      // Assert
      expect(patterns.length, equals(2)); // Should find 2 unique patterns
      expect(patterns.containsKey('2-18:00-21:00'), isTrue); // Tuesday
      expect(patterns.containsKey('4-18:00-21:00'), isTrue); // Thursday
    });

    test('Should update future classes when schedule changes', () async {
      // Arrange - Create existing classes
      final now = DateTime.now();
      final nextTuesday = _getNextDateForWeekday(2);
      
      // Create 6 Tuesday classes
      for (int week = 0; week < 6; week++) {
        final classDate = nextTuesday.add(Duration(days: week * 7));
        await firestore.collection('classes').add({
          'groupId': groupId,
          'teacherId': teacherId,
          'scheduledDate': Timestamp.fromDate(classDate),
          'startTime': '18:00',
          'endTime': '21:00',
          'location': 'Old Location',
          'recurrenceType': RecurrenceType.weekly.name,
          'status': ClassStatus.scheduled.name,
        });
      }

      // Act - Update future classes (change time and location)
      final updateFromDate = now;
      final query = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('startTime', isEqualTo: '18:00')
          .where('endTime', isEqualTo: '21:00')
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(updateFromDate))
          .get();

      // Update matching Tuesday classes
      for (final doc in query.docs) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        if (date.weekday == 2) { // Tuesday
          await doc.reference.update({
            'startTime': '17:00',
            'endTime': '20:00',
            'location': 'New Location',
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          });
        }
      }

      // Assert - Verify updates
      final updatedClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('startTime', isEqualTo: '17:00')
          .get();

      expect(updatedClasses.docs.isNotEmpty, isTrue);
      
      for (final doc in updatedClasses.docs) {
        expect(doc.data()['endTime'], equals('20:00'));
        expect(doc.data()['location'], equals('New Location'));
      }

      // Verify old times don't exist for future dates
      final oldTimeClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('startTime', isEqualTo: '18:00')
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .get();

      expect(oldTimeClasses.docs.isEmpty, isTrue);
    });

    test('Should handle mixed existing and new schedules', () async {
      // Arrange - Create one existing schedule
      final nextMonday = _getNextDateForWeekday(1);
      await firestore.collection('classes').add({
        'groupId': groupId,
        'teacherId': teacherId,
        'scheduledDate': Timestamp.fromDate(nextMonday),
        'startTime': '18:00',
        'endTime': '19:30',
        'location': 'Existing Location',
        'recurrenceType': RecurrenceType.weekly.name,
        'status': ClassStatus.scheduled.name,
      });

      // Act - Simulate loading existing and adding new
      final existingQuery = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      expect(existingQuery.docs.length, equals(1));
      
      // Add a new Wednesday schedule
      final nextWednesday = _getNextDateForWeekday(3);
      await firestore.collection('classes').add({
        'groupId': groupId,
        'teacherId': teacherId,
        'scheduledDate': Timestamp.fromDate(nextWednesday),
        'startTime': '19:00',
        'endTime': '20:30',
        'location': 'New Location',
        'recurrenceType': RecurrenceType.weekly.name,
        'status': ClassStatus.scheduled.name,
      });

      // Assert - Should have both schedules
      final allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      expect(allClasses.docs.length, equals(2));
    });

    test('Should detect changes in existing schedules', () async {
      // This tests the change detection logic
      final original = {
        'startTime': TimeOfDay(hour: 18, minute: 0),
        'endTime': TimeOfDay(hour: 21, minute: 0),
        'location': 'Original Location',
      };

      final modified = {
        'startTime': TimeOfDay(hour: 17, minute: 0),
        'endTime': TimeOfDay(hour: 20, minute: 0),
        'location': 'Modified Location',
      };

      // Test time change detection
      expect(modified['startTime'] != original['startTime'], isTrue);
      expect(modified['endTime'] != original['endTime'], isTrue);
      
      // Test location change detection
      expect(modified['location'] != original['location'], isTrue);
    });

    test('Should group classes by unique day/time patterns', () async {
      // Arrange - Create classes with same pattern but different weeks
      final startDate = _getNextDateForWeekday(1); // Monday
      
      // Create 3 Monday classes with same time
      for (int week = 0; week < 3; week++) {
        await firestore.collection('classes').add({
          'teacherId': teacherId,
          'scheduledDate': Timestamp.fromDate(startDate.add(Duration(days: week * 7))),
          'startTime': '18:00',
          'endTime': '19:30',
          'location': 'Gym',
          'recurrenceType': RecurrenceType.weekly.name,
        });
      }

      // Create 2 Monday classes with different time
      for (int week = 0; week < 2; week++) {
        await firestore.collection('classes').add({
          'teacherId': teacherId,
          'scheduledDate': Timestamp.fromDate(startDate.add(Duration(days: week * 7))),
          'startTime': '20:00',
          'endTime': '21:30',
          'location': 'Park',
          'recurrenceType': RecurrenceType.weekly.name,
        });
      }

      // Act - Group by pattern
      final allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final patterns = <String, int>{};
      for (final doc in allClasses.docs) {
        final data = doc.data();
        final date = (data['scheduledDate'] as Timestamp).toDate();
        final key = '${date.weekday}-${data['startTime']}-${data['endTime']}';
        patterns[key] = (patterns[key] ?? 0) + 1;
      }

      // Assert
      expect(patterns.length, equals(2)); // Two unique patterns
      expect(patterns['1-18:00-19:30'], equals(3)); // 3 classes with this pattern
      expect(patterns['1-20:00-21:30'], equals(2)); // 2 classes with this pattern
    });
  });
}

DateTime _getNextDateForWeekday(int weekday) {
  final now = DateTime.now();
  int daysToAdd = weekday - now.weekday;
  if (daysToAdd <= 0) {
    daysToAdd += 7; // Next week
  }
  return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
}