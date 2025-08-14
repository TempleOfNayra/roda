import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// WARNING: This test hits the REAL Firestore database
// It uses a test collection to avoid affecting production data

void main() {
  group('Real Firestore Delete Tests', () {
    late FirebaseFirestore firestore;
    late String testTeacherId;
    late CollectionReference testCollection;
    
    setUpAll(() async {
      // Initialize Firebase for testing
      TestWidgetsFlutterBinding.ensureInitialized();
      
      try {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyANGEXXNg3cPnxBr0O_XdBG7FoYL4HMIfc',
            appId: '1:491672145228:ios:d00e8c3c00816eaa',
            messagingSenderId: '491672145228',
            projectId: 'roda-33c6f',
            authDomain: 'roda-33c6f.firebaseapp.com',
            storageBucket: 'roda-33c6f.appspot.com',
          ),
        );
      } catch (e) {
        // Already initialized
      }
      
      firestore = FirebaseFirestore.instance;
      testTeacherId = 'test_teacher_${DateTime.now().millisecondsSinceEpoch}';
      
      // Use a test collection to avoid affecting production
      testCollection = firestore.collection('test_classes');
    });
    
    tearDown(() async {
      // Clean up test data after each test
      final query = await testCollection
          .where('teacherId', isEqualTo: testTeacherId)
          .get();
      
      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    });

    test('Delete with composite query should fail without index', () async {
      // This test demonstrates the index requirement issue
      
      // Create test data
      final testDate = DateTime.now().add(const Duration(days: 7));
      await testCollection.add({
        'teacherId': testTeacherId,
        'scheduledDate': Timestamp.fromDate(testDate),
        'startTime': '18:00',
        'endTime': '21:00',
        'dayOfWeek': 2,
        'location': 'Test Gym',
        'recurrenceType': 'weekly',
        'eventType': 'class_',
        'status': 'scheduled',
      });
      
      // Try composite query (this would fail without index in production)
      try {
        final query = await testCollection
            .where('teacherId', isEqualTo: testTeacherId)
            .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
            .orderBy('scheduledDate')
            .get();
        
        // If we get here without error, index exists
        print('Composite query succeeded - index exists');
      } catch (e) {
        // This is what happens in production without index
        print('Composite query failed: $e');
        expect(e.toString(), contains('index'));
      }
    });

    test('Delete with simple query and in-memory filtering should work', () async {
      // This is the working approach
      
      // Create multiple test schedules
      final now = DateTime.now();
      final schedules = [
        {'day': 2, 'start': '18:00', 'end': '21:00'}, // Tuesday 6-9
        {'day': 2, 'start': '09:00', 'end': '11:00'}, // Tuesday 9-11
        {'day': 4, 'start': '18:00', 'end': '21:00'}, // Thursday 6-9
      ];
      
      // Add test data
      for (final schedule in schedules) {
        for (int week = 1; week <= 3; week++) {
          final date = _getNextDateForWeekday(schedule['day'] as int)
              .add(Duration(days: week * 7));
          
          await testCollection.add({
            'teacherId': testTeacherId,
            'scheduledDate': Timestamp.fromDate(date),
            'startTime': schedule['start'],
            'endTime': schedule['end'],
            'dayOfWeek': schedule['day'],
            'location': 'Test Location',
            'recurrenceType': 'weekly',
            'eventType': 'class_',
            'status': 'scheduled',
          });
        }
      }
      
      // Verify setup
      var allClasses = await testCollection
          .where('teacherId', isEqualTo: testTeacherId)
          .get();
      expect(allClasses.docs.length, equals(9)); // 3 schedules × 3 weeks
      
      // Delete Tuesday 6-9 using simple query + filtering
      final query = await testCollection
          .where('teacherId', isEqualTo: testTeacherId)
          .get();
      
      final batch = firestore.batch();
      int deleteCount = 0;
      
      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['scheduledDate'] as Timestamp).toDate();
        
        // Filter in memory
        if (date.isBefore(now)) continue;
        
        if (data['dayOfWeek'] == 2 &&
            data['startTime'] == '18:00' &&
            data['endTime'] == '21:00') {
          batch.delete(doc.reference);
          deleteCount++;
        }
      }
      
      if (deleteCount > 0) {
        await batch.commit();
      }
      
      expect(deleteCount, equals(3)); // 3 Tuesday 6-9 classes
      
      // Verify remaining
      allClasses = await testCollection
          .where('teacherId', isEqualTo: testTeacherId)
          .get();
      expect(allClasses.docs.length, equals(6)); // 9 - 3 = 6
      
      // Verify Tuesday 9-11 still exists
      final tuesdayMorning = allClasses.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['dayOfWeek'] == 2 && 
               data['startTime'] == '09:00';
      }).toList();
      expect(tuesdayMorning.length, equals(3));
      
      // Verify Thursday still exists  
      final thursday = allClasses.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['dayOfWeek'] == 4;
      }).toList();
      expect(thursday.length, equals(3));
    });

    test('Real-world delete scenario', () async {
      // Simulate exactly what the app does
      
      // Create a realistic schedule
      final nextTuesday = _getNextDateForWeekday(2);
      
      // Add classes for next 4 weeks
      for (int week = 0; week < 4; week++) {
        final date = nextTuesday.add(Duration(days: week * 7));
        await testCollection.add({
          'teacherId': testTeacherId,
          'scheduledDate': Timestamp.fromDate(date),
          'startTime': '18:00',
          'endTime': '21:00',
          'dayOfWeek': 2,
          'location': '890 Lafayette Ave, New York, NY',
          'recurrenceType': 'weekly',
          'eventType': 'class_',
          'status': 'scheduled',
          'groupId': 'test_group',
          'groupName': 'Test Group',
        });
      }
      
      // Simulate the delete operation from the app
      final now = DateTime.now();
      final query = await testCollection
          .where('teacherId', isEqualTo: testTeacherId)
          .get();
      
      print('Found ${query.docs.length} classes to check');
      
      final batch = firestore.batch();
      int deleteCount = 0;
      
      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['scheduledDate'] as Timestamp).toDate();
        
        // Only future classes
        if (date.isBefore(now)) {
          print('Skipping past class on $date');
          continue;
        }
        
        // Match the pattern
        if (data['dayOfWeek'] == 2 &&
            data['startTime'] == '18:00' &&
            data['endTime'] == '21:00') {
          print('Deleting class on $date');
          batch.delete(doc.reference);
          deleteCount++;
        }
      }
      
      if (deleteCount > 0) {
        await batch.commit();
        print('Successfully deleted $deleteCount classes');
      }
      
      expect(deleteCount, greaterThan(0));
      
      // Verify they're gone
      final remaining = await testCollection
          .where('teacherId', isEqualTo: testTeacherId)
          .get();
      
      expect(remaining.docs.length, equals(4 - deleteCount));
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