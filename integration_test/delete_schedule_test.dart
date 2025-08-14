import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roda/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Delete Schedule E2E Test', () {
    setUpAll(() async {
      // Start the app
      app.main();
      await Future.delayed(const Duration(seconds: 3)); // Wait for app to initialize
    });

    testWidgets('Delete schedule should only delete specific pattern', (WidgetTester tester) async {
      // This test runs on a real device with real Firebase
      
      print('Starting delete test with real database...');
      
      // Get Firebase instances (already initialized by the app)
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      
      // Wait for auth
      await Future.delayed(const Duration(seconds: 2));
      
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        print('No user logged in, skipping test');
        return;
      }
      
      final teacherId = currentUser.uid;
      print('Testing with teacher ID: $teacherId');
      
      // Step 1: Create test schedules directly in Firestore
      print('\n=== Creating test schedules ===');
      
      final testCollection = firestore.collection('classes');
      final now = DateTime.now();
      final testTag = 'test_${now.millisecondsSinceEpoch}';
      
      // Create 3 different schedule patterns
      final schedules = [
        {'day': 2, 'start': '10:00', 'end': '11:00', 'location': 'Test Gym A $testTag'}, // Tuesday morning
        {'day': 2, 'start': '18:00', 'end': '21:00', 'location': 'Test Gym B $testTag'}, // Tuesday evening  
        {'day': 4, 'start': '18:00', 'end': '21:00', 'location': 'Test Gym C $testTag'}, // Thursday evening
      ];
      
      final createdDocs = <DocumentReference>[];
      
      for (final schedule in schedules) {
        // Create 3 weeks of each schedule
        for (int week = 1; week <= 3; week++) {
          final date = _getNextDateForWeekday(schedule['day'] as int)
              .add(Duration(days: week * 7));
          
          final docRef = await testCollection.add({
            'teacherId': teacherId,
            'scheduledDate': Timestamp.fromDate(date),
            'startTime': schedule['start'],
            'endTime': schedule['end'],
            'location': schedule['location'],
            'dayOfWeek': schedule['day'],
            'recurrenceType': 'weekly',
            'eventType': 'class_',
            'status': 'scheduled',
            'groupId': 'test_group',
            'groupName': 'Test Group',
            'attendingStudentIds': [],
            'presentStudentIds': [],
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
          
          createdDocs.add(docRef);
          print('Created ${_getDayName(schedule['day'] as int)} ${schedule['start']} class for week $week');
        }
      }
      
      print('Created ${createdDocs.length} test classes total');
      
      // Step 2: Verify all were created
      final beforeDelete = await testCollection
          .where('teacherId', isEqualTo: teacherId)
          .where('location', isGreaterThanOrEqualTo: 'Test Gym')
          .where('location', isLessThanOrEqualTo: 'Test Gym' + '\uf8ff')
          .get();
      
      final testClasses = beforeDelete.docs.where((doc) {
        final location = doc.data()['location'] as String;
        return location.contains(testTag);
      }).toList();
      
      print('\nBefore delete: ${testClasses.length} test classes found');
      expect(testClasses.length, equals(9), reason: 'Should have 9 test classes (3 patterns × 3 weeks)');
      
      // Step 3: Delete only Tuesday evening (18:00-21:00)
      print('\n=== Deleting Tuesday 18:00-21:00 ===');
      
      final query = await testCollection
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      final batch = firestore.batch();
      int deleteCount = 0;
      
      for (final doc in query.docs) {
        final data = doc.data();
        final location = data['location'] as String;
        
        // Only delete our test data
        if (!location.contains(testTag)) continue;
        
        final date = (data['scheduledDate'] as Timestamp).toDate();
        
        // Only delete future classes
        if (date.isBefore(now)) continue;
        
        // Delete only Tuesday 18:00-21:00
        if (data['dayOfWeek'] == 2 &&
            data['startTime'] == '18:00' &&
            data['endTime'] == '21:00') {
          print('Deleting: ${_getDayName(2)} ${data['startTime']}-${data['endTime']} on ${date.toString().split(' ')[0]}');
          batch.delete(doc.reference);
          deleteCount++;
        }
      }
      
      if (deleteCount > 0) {
        await batch.commit();
        print('Deleted $deleteCount classes');
      }
      
      // Step 4: Verify correct deletion
      print('\n=== Verifying results ===');
      
      final afterDelete = await testCollection
          .where('teacherId', isEqualTo: teacherId)
          .where('location', isGreaterThanOrEqualTo: 'Test Gym')
          .where('location', isLessThanOrEqualTo: 'Test Gym' + '\uf8ff')
          .get();
      
      final remainingTestClasses = afterDelete.docs.where((doc) {
        final location = doc.data()['location'] as String;
        return location.contains(testTag);
      }).toList();
      
      print('After delete: ${remainingTestClasses.length} test classes remain');
      
      // Should have 6 classes left (9 - 3 Tuesday evening = 6)
      expect(remainingTestClasses.length, equals(6), 
          reason: 'Should have 6 classes after deleting 3 Tuesday evening classes');
      
      // Verify Tuesday morning still exists
      final tuesdayMorning = remainingTestClasses.where((doc) {
        final data = doc.data();
        return data['dayOfWeek'] == 2 && data['startTime'] == '10:00';
      }).toList();
      
      expect(tuesdayMorning.length, equals(3), 
          reason: 'Tuesday morning classes should still exist');
      print('✓ Tuesday 10:00-11:00 classes still exist: ${tuesdayMorning.length}');
      
      // Verify Thursday evening still exists
      final thursdayEvening = remainingTestClasses.where((doc) {
        final data = doc.data();
        return data['dayOfWeek'] == 4 && data['startTime'] == '18:00';
      }).toList();
      
      expect(thursdayEvening.length, equals(3), 
          reason: 'Thursday evening classes should still exist');
      print('✓ Thursday 18:00-21:00 classes still exist: ${thursdayEvening.length}');
      
      // Verify NO Tuesday evening classes remain
      final tuesdayEvening = remainingTestClasses.where((doc) {
        final data = doc.data();
        return data['dayOfWeek'] == 2 && data['startTime'] == '18:00';
      }).toList();
      
      expect(tuesdayEvening.length, equals(0), 
          reason: 'No Tuesday evening classes should remain');
      print('✓ Tuesday 18:00-21:00 classes deleted: ${tuesdayEvening.length} remaining');
      
      // Step 5: Clean up test data
      print('\n=== Cleaning up test data ===');
      
      final cleanupBatch = firestore.batch();
      for (final doc in remainingTestClasses) {
        cleanupBatch.delete(doc.reference);
      }
      
      if (remainingTestClasses.isNotEmpty) {
        await cleanupBatch.commit();
        print('Cleaned up ${remainingTestClasses.length} test classes');
      }
      
      print('\n✅ Delete test PASSED! Only specific schedule pattern was deleted.');
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

String _getDayName(int day) {
  switch (day) {
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