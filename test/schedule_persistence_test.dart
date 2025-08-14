import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() {
  group('Schedule Persistence Test', () {
    late FakeFirebaseFirestore firestore;
    late String teacherId;
    late String groupId;
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
      teacherId = 'test_teacher_123';
      groupId = 'test_group_456';
    });

    test('Complete schedule workflow with persistence', () async {
      print('\n========================================');
      print('SCHEDULE PERSISTENCE TEST');
      print('========================================\n');
      
      // Helper function to simulate loading existing schedules
      Future<List<Map<String, dynamic>>> loadExistingSchedules() async {
        final now = DateTime.now();
        final endDate = now.add(const Duration(days: 30));
        
        final classesSnapshot = await firestore
            .collection('classes')
            .where('teacherId', isEqualTo: teacherId)
            .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
            .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
            .where('recurrenceType', whereIn: ['weekly', 'monthly'])
            .orderBy('scheduledDate')
            .get();
        
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
              'isExisting': true,
            };
          }
        }
        
        return patterns.values.toList();
      }
      
      // Helper to create classes for a schedule
      Future<void> createClassesForSchedule(Map<String, dynamic> schedule) async {
        final nextDate = _getNextDateForWeekday(schedule['dayOfWeek']);
        
        // Create 8 weeks of classes
        for (int week = 0; week < 8; week++) {
          final classDate = nextDate.add(Duration(days: week * 7));
          
          await firestore.collection('classes').add({
            'teacherId': teacherId,
            'groupId': groupId,
            'scheduledDate': Timestamp.fromDate(classDate),
            'startTime': schedule['startTime'],
            'endTime': schedule['endTime'],
            'location': schedule['location'] ?? 'Default Location',
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
      
      // ===== STEP 1: Schedule Tuesday 6-9 class =====
      print('STEP 1: Scheduling Tuesday 6-9 class');
      print('--------------------------------------');
      
      await createClassesForSchedule({
        'dayOfWeek': 2, // Tuesday
        'startTime': '18:00',
        'endTime': '21:00',
        'location': 'Main Gym',
      });
      
      // Verify Tuesday class was created
      var allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      print('✓ Created ${allClasses.docs.length} Tuesday classes');
      expect(allClasses.docs.length, equals(8));
      
      // ===== STEP 2: Leave and return to page =====
      print('\nSTEP 2: Leaving page and returning...');
      print('--------------------------------------');
      
      // Simulate loading existing schedules when returning to page
      var existingSchedules = await loadExistingSchedules();
      
      print('✓ Found ${existingSchedules.length} existing schedule pattern(s)');
      expect(existingSchedules.length, equals(1));
      expect(existingSchedules[0]['dayOfWeek'], equals(2)); // Tuesday
      expect(existingSchedules[0]['startTime'], equals('18:00'));
      expect(existingSchedules[0]['endTime'], equals('21:00'));
      
      print('  Tuesday: ${existingSchedules[0]['startTime']}-${existingSchedules[0]['endTime']}');
      
      // ===== STEP 3: Add Wednesday 7-9 class =====
      print('\nSTEP 3: Adding Wednesday 7-9 class');
      print('--------------------------------------');
      
      await createClassesForSchedule({
        'dayOfWeek': 3, // Wednesday
        'startTime': '19:00',
        'endTime': '21:00',
        'location': 'Main Gym',
      });
      
      allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      print('✓ Total classes now: ${allClasses.docs.length}');
      expect(allClasses.docs.length, equals(16)); // 8 Tuesday + 8 Wednesday
      
      // ===== STEP 4: Leave and return again =====
      print('\nSTEP 4: Leaving page and returning again...');
      print('--------------------------------------');
      
      existingSchedules = await loadExistingSchedules();
      
      print('✓ Found ${existingSchedules.length} existing schedule patterns');
      expect(existingSchedules.length, equals(2));
      
      // Sort by day of week for consistent testing
      existingSchedules.sort((a, b) => a['dayOfWeek'].compareTo(b['dayOfWeek']));
      
      print('  Tuesday: ${existingSchedules[0]['startTime']}-${existingSchedules[0]['endTime']}');
      print('  Wednesday: ${existingSchedules[1]['startTime']}-${existingSchedules[1]['endTime']}');
      
      expect(existingSchedules[0]['dayOfWeek'], equals(2)); // Tuesday
      expect(existingSchedules[0]['startTime'], equals('18:00'));
      expect(existingSchedules[0]['endTime'], equals('21:00'));
      
      expect(existingSchedules[1]['dayOfWeek'], equals(3)); // Wednesday
      expect(existingSchedules[1]['startTime'], equals('19:00'));
      expect(existingSchedules[1]['endTime'], equals('21:00'));
      
      // ===== STEP 5: Add Friday 4-5 class =====
      print('\nSTEP 5: Adding Friday 4-5 class');
      print('--------------------------------------');
      
      await createClassesForSchedule({
        'dayOfWeek': 5, // Friday
        'startTime': '16:00',
        'endTime': '17:00',
        'location': 'Beach Park',
      });
      
      allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      print('✓ Total classes now: ${allClasses.docs.length}');
      expect(allClasses.docs.length, equals(24)); // 8 Tuesday + 8 Wednesday + 8 Friday
      
      // ===== STEP 6: Edit Tuesday from 6-9 to 5-8 =====
      print('\nSTEP 6: Editing Tuesday from 6-9 (18:00-21:00) to 5-8 (17:00-20:00)');
      print('--------------------------------------------------------------------');
      
      // Update all future Tuesday classes
      final now = DateTime.now();
      final tuesdayClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('startTime', isEqualTo: '18:00')
          .where('endTime', isEqualTo: '21:00')
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .get();
      
      int updatedCount = 0;
      for (final doc in tuesdayClasses.docs) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        if (date.weekday == 2) { // Tuesday
          await doc.reference.update({
            'startTime': '17:00',
            'endTime': '20:00',
            'updatedAt': Timestamp.now(),
          });
          updatedCount++;
        }
      }
      
      print('✓ Updated $updatedCount Tuesday classes');
      
      // ===== STEP 7: Leave and return to verify final state =====
      print('\nSTEP 7: Final verification after leaving and returning');
      print('-------------------------------------------------------');
      
      existingSchedules = await loadExistingSchedules();
      
      print('✓ Found ${existingSchedules.length} schedule patterns');
      expect(existingSchedules.length, equals(3));
      
      // Sort by day of week for consistent testing
      existingSchedules.sort((a, b) => a['dayOfWeek'].compareTo(b['dayOfWeek']));
      
      print('\nFinal Schedule:');
      print('  Tuesday: ${existingSchedules[0]['startTime']}-${existingSchedules[0]['endTime']}');
      print('  Wednesday: ${existingSchedules[1]['startTime']}-${existingSchedules[1]['endTime']}');
      print('  Friday: ${existingSchedules[2]['startTime']}-${existingSchedules[2]['endTime']}');
      
      // Verify Tuesday is now 5-8 (17:00-20:00)
      expect(existingSchedules[0]['dayOfWeek'], equals(2)); // Tuesday
      expect(existingSchedules[0]['startTime'], equals('17:00'));
      expect(existingSchedules[0]['endTime'], equals('20:00'));
      
      // Verify Wednesday is still 7-9 (19:00-21:00)
      expect(existingSchedules[1]['dayOfWeek'], equals(3)); // Wednesday
      expect(existingSchedules[1]['startTime'], equals('19:00'));
      expect(existingSchedules[1]['endTime'], equals('21:00'));
      
      // Verify Friday is 4-5 (16:00-17:00)
      expect(existingSchedules[2]['dayOfWeek'], equals(5)); // Friday
      expect(existingSchedules[2]['startTime'], equals('16:00'));
      expect(existingSchedules[2]['endTime'], equals('17:00'));
      
      // ===== FINAL VERIFICATION OF ALL CLASSES =====
      print('\nFINAL DATABASE STATE:');
      print('---------------------');
      
      // Get all classes and group by pattern
      allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('scheduledDate')
          .get();
      
      final classCounts = <String, int>{};
      for (final doc in allClasses.docs) {
        final data = doc.data();
        final date = (data['scheduledDate'] as Timestamp).toDate();
        final key = '${_getDayName(date.weekday)} ${data['startTime']}-${data['endTime']}';
        classCounts[key] = (classCounts[key] ?? 0) + 1;
      }
      
      print('Class distribution:');
      classCounts.forEach((pattern, count) {
        print('  $pattern: $count classes');
      });
      
      // Verify no old Tuesday time exists
      expect(classCounts.containsKey('Tuesday 18:00-21:00'), isFalse);
      
      // Verify correct patterns exist
      expect(classCounts['Tuesday 17:00-20:00'], equals(8));
      expect(classCounts['Wednesday 19:00-21:00'], equals(8));
      expect(classCounts['Friday 16:00-17:00'], equals(8));
      
      print('\n========================================');
      print('✅ ALL TESTS PASSED!');
      print('========================================');
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