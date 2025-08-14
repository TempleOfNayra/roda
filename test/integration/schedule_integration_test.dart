import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() {
  group('Schedule Integration Tests', () {
    late FakeFirebaseFirestore firestore;
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
    });

    test('Full schedule workflow: Create, Load, Edit, Update', () async {
      // PHASE 1: Teacher creates initial schedule
      print('\n=== PHASE 1: Creating Initial Schedule ===');
      
      final teacherId = 'teacher_123';
      final groupId = 'group_456';
      
      // Teacher schedules Tuesday and Thursday classes
      final initialSchedules = [
        {
          'dayOfWeek': 2, // Tuesday
          'startTime': '18:00',
          'endTime': '21:00',
          'location': 'Community Gym',
        },
        {
          'dayOfWeek': 4, // Thursday
          'startTime': '18:00',
          'endTime': '21:00',
          'location': 'Community Gym',
        },
      ];
      
      // Create 8 weeks of classes
      for (final schedule in initialSchedules) {
        for (int week = 0; week < 8; week++) {
          final classDate = _getNextDateForWeekday(schedule['dayOfWeek'] as int)
              .add(Duration(days: week * 7));
          
          await firestore.collection('classes').add({
            'teacherId': teacherId,
            'groupId': groupId,
            'scheduledDate': Timestamp.fromDate(classDate),
            'startTime': schedule['startTime'],
            'endTime': schedule['endTime'],
            'location': schedule['location'],
            'recurrenceType': 'weekly',
            'eventType': 'class_',
            'status': 'scheduled',
            'attendingStudentIds': [],
            'presentStudentIds': [],
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
        }
      }
      
      final createdClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      print('Created ${createdClasses.docs.length} classes');
      expect(createdClasses.docs.length, equals(16)); // 2 days × 8 weeks
      
      // PHASE 2: Load existing schedules (simulating enhanced_schedule_page)
      print('\n=== PHASE 2: Loading Existing Schedules ===');
      
      final now = DateTime.now();
      final endDate = now.add(Duration(days: 30));
      
      final existingClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('recurrenceType', whereIn: ['weekly', 'monthly'])
          .orderBy('scheduledDate')
          .get();
      
      print('Found ${existingClasses.docs.length} classes in next 30 days');
      
      // Group by unique patterns
      final patterns = <String, Map<String, dynamic>>{};
      for (final doc in existingClasses.docs) {
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
            'originalStartTime': startTime,
            'originalEndTime': endTime,
            'originalLocation': location,
            'isExisting': true,
          };
        }
      }
      
      print('Found ${patterns.length} unique schedule patterns');
      expect(patterns.length, equals(2)); // Tuesday and Thursday
      
      // PHASE 3: Teacher edits Tuesday schedule
      print('\n=== PHASE 3: Editing Tuesday Schedule ===');
      
      // Simulate teacher changing Tuesday from 18:00-21:00 to 17:00-20:00
      final tuesdayPattern = patterns['2-18:00-21:00']!;
      expect(tuesdayPattern, isNotNull);
      
      // Detect change
      final hasChanges = tuesdayPattern['startTime'] != '17:00' ||
                        tuesdayPattern['endTime'] != '20:00' ||
                        tuesdayPattern['location'] != 'New Beach Location';
      
      expect(hasChanges, isTrue);
      print('Changes detected in Tuesday schedule');
      
      // PHASE 4: Update all future Tuesday classes
      print('\n=== PHASE 4: Updating Future Classes ===');
      
      // Query for all future Tuesday classes with old time
      final tuesdayClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('startTime', isEqualTo: '18:00')
          .where('endTime', isEqualTo: '21:00')
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .get();
      
      print('Found ${tuesdayClasses.docs.length} future classes to update');
      
      int updatedCount = 0;
      for (final doc in tuesdayClasses.docs) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        if (date.weekday == 2) { // Tuesday
          await doc.reference.update({
            'startTime': '17:00',
            'endTime': '20:00',
            'location': 'New Beach Location',
            'updatedAt': Timestamp.now(),
          });
          updatedCount++;
        }
      }
      
      print('Updated $updatedCount Tuesday classes');
      
      // PHASE 5: Verify updates
      print('\n=== PHASE 5: Verifying Updates ===');
      
      // Check Tuesday classes have new time
      final updatedTuesdayClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('startTime', isEqualTo: '17:00')
          .where('endTime', isEqualTo: '20:00')
          .get();
      
      print('Found ${updatedTuesdayClasses.docs.length} updated Tuesday classes');
      expect(updatedTuesdayClasses.docs.isNotEmpty, isTrue);
      
      // Verify all are Tuesday and have new location
      for (final doc in updatedTuesdayClasses.docs) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        expect(date.weekday, equals(2)); // All should be Tuesday
        expect(doc.data()['location'], equals('New Beach Location'));
      }
      
      // Check Thursday classes unchanged
      final thursdayClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('startTime', isEqualTo: '18:00')
          .where('endTime', isEqualTo: '21:00')
          .get();
      
      print('Found ${thursdayClasses.docs.length} unchanged Thursday classes');
      
      // All remaining 18:00-21:00 classes should be Thursday
      for (final doc in thursdayClasses.docs) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        expect(date.weekday, equals(4)); // All should be Thursday
        expect(doc.data()['location'], equals('Community Gym')); // Original location
      }
      
      // PHASE 6: Add new Friday schedule
      print('\n=== PHASE 6: Adding New Friday Schedule ===');
      
      // Teacher adds Friday classes
      for (int week = 0; week < 4; week++) {
        final classDate = _getNextDateForWeekday(5) // Friday
            .add(Duration(days: week * 7));
        
        await firestore.collection('classes').add({
          'teacherId': teacherId,
          'groupId': groupId,
          'scheduledDate': Timestamp.fromDate(classDate),
          'startTime': '16:00',
          'endTime': '17:30',
          'location': 'Park',
          'recurrenceType': 'weekly',
          'eventType': 'class_',
          'status': 'scheduled',
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
        });
      }
      
      // Final verification
      print('\n=== FINAL VERIFICATION ===');
      
      final allFinalClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('scheduledDate')
          .get();
      
      print('Total classes: ${allFinalClasses.docs.length}');
      
      // Group by day and time for summary
      final summary = <String, int>{};
      for (final doc in allFinalClasses.docs) {
        final data = doc.data();
        final date = (data['scheduledDate'] as Timestamp).toDate();
        final key = '${_getDayName(date.weekday)} ${data['startTime']}-${data['endTime']}';
        summary[key] = (summary[key] ?? 0) + 1;
      }
      
      print('\nSchedule Summary:');
      summary.forEach((pattern, count) {
        print('  $pattern: $count classes');
      });
      
      // Verify final state
      expect(summary.containsKey('Tuesday 17:00-20:00'), isTrue);
      expect(summary.containsKey('Thursday 18:00-21:00'), isTrue);
      expect(summary.containsKey('Friday 16:00-17:30'), isTrue);
      expect(summary.containsKey('Tuesday 18:00-21:00'), isFalse); // Old time should not exist
      
      print('\n✅ All integration tests passed!');
    });
  });
}

DateTime _getNextDateForWeekday(int weekday) {
  final now = DateTime.now();
  int daysToAdd = weekday - now.weekday;
  if (daysToAdd <= 0) {
    daysToAdd += 7;
  }
  return DateTime(now.year, now.month, now.day).add(Duration(days: daysToAdd));
}

String _getDayName(int weekday) {
  switch (weekday) {
    case 1: return 'Monday';
    case 2: return 'Tuesday';
    case 3: return 'Wednesday';
    case 4: return 'Thursday';
    case 5: return 'Friday';
    case 6: return 'Saturday';
    case 7: return 'Sunday';
    default: return 'Unknown';
  }
}