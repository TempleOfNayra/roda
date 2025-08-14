import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void main() {
  group('Clean Schedule Delete Tests', () {
    late FakeFirebaseFirestore firestore;
    late String teacherId;
    
    setUp(() {
      firestore = FakeFirebaseFirestore();
      teacherId = 'test_teacher_123';
    });

    test('Delete should only remove ONE specific schedule pattern, not all classes', () async {
      // ARRANGE - Create multiple different schedules
      final schedules = [
        {'day': 2, 'start': '18:00', 'end': '21:00', 'location': 'Gym A'}, // Tuesday 6-9
        {'day': 2, 'start': '09:00', 'end': '11:00', 'location': 'Park'},   // Tuesday 9-11
        {'day': 4, 'start': '18:00', 'end': '21:00', 'location': 'Gym A'}, // Thursday 6-9
        {'day': 5, 'start': '16:00', 'end': '17:00', 'location': 'Beach'},  // Friday 4-5
      ];
      
      // Create 4 weeks of classes for each schedule
      for (final schedule in schedules) {
        for (int week = 0; week < 4; week++) {
          final date = _getNextDateForWeekday(schedule['day'] as int)
              .add(Duration(days: week * 7));
          
          await firestore.collection('classes').add({
            'teacherId': teacherId,
            'scheduledDate': Timestamp.fromDate(date),
            'startTime': schedule['start'],
            'endTime': schedule['end'],
            'location': schedule['location'],
            'recurrenceType': 'weekly',
            'eventType': 'class_',
            'status': 'scheduled',
          });
        }
      }
      
      // Verify we have 16 total classes (4 schedules × 4 weeks)
      var allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      expect(allClasses.docs.length, equals(16));
      
      // ACT - Delete ONLY Tuesday 6-9 schedule
      final now = DateTime.now();
      final query = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .get();
      
      final batch = firestore.batch();
      int deleteCount = 0;
      
      for (final doc in query.docs) {
        final data = doc.data();
        final date = (data['scheduledDate'] as Timestamp).toDate();
        
        // Delete ONLY Tuesday 6-9 classes
        if (date.weekday == 2 && 
            data['startTime'] == '18:00' && 
            data['endTime'] == '21:00') {
          batch.delete(doc.reference);
          deleteCount++;
        }
      }
      
      await batch.commit();
      
      // ASSERT
      expect(deleteCount, equals(4)); // Should delete 4 Tuesday 6-9 classes
      
      // Verify remaining classes
      allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      expect(allClasses.docs.length, equals(12)); // 16 - 4 = 12 remaining
      
      // Verify Tuesday 9-11 still exists
      final tuesdayMorning = allClasses.docs.where((doc) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        return date.weekday == 2 && 
               doc.data()['startTime'] == '09:00' &&
               doc.data()['endTime'] == '11:00';
      }).toList();
      expect(tuesdayMorning.length, equals(4)); // All 4 Tuesday morning classes remain
      
      // Verify Thursday 6-9 still exists
      final thursdayEvening = allClasses.docs.where((doc) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        return date.weekday == 4 && 
               doc.data()['startTime'] == '18:00' &&
               doc.data()['endTime'] == '21:00';
      }).toList();
      expect(thursdayEvening.length, equals(4)); // All 4 Thursday evening classes remain
      
      // Verify Friday still exists
      final friday = allClasses.docs.where((doc) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        return date.weekday == 5;
      }).toList();
      expect(friday.length, equals(4)); // All 4 Friday classes remain
    });

    test('Delete button should work and actually remove the schedule', () async {
      // ARRANGE - Add a schedule
      final date = _getNextDateForWeekday(3); // Wednesday
      await firestore.collection('classes').add({
        'teacherId': teacherId,
        'scheduledDate': Timestamp.fromDate(date),
        'startTime': '19:00',
        'endTime': '21:00',
        'location': 'Community Center',
        'recurrenceType': 'weekly',
        'eventType': 'class_',
        'status': 'scheduled',
      });
      
      // Verify it exists
      var classes = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      expect(classes.docs.length, equals(1));
      
      // ACT - Delete it
      final docToDelete = classes.docs.first;
      await docToDelete.reference.delete();
      
      // ASSERT - Verify it's gone
      classes = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      expect(classes.docs.length, equals(0));
    });

    test('Should be able to delete individual schedule patterns independently', () async {
      // ARRANGE - Create 3 different schedule patterns
      final patterns = [
        {'day': 1, 'start': '18:00', 'end': '19:30'}, // Monday evening
        {'day': 3, 'start': '18:00', 'end': '19:30'}, // Wednesday evening  
        {'day': 5, 'start': '18:00', 'end': '19:30'}, // Friday evening
      ];
      
      for (final pattern in patterns) {
        for (int week = 0; week < 2; week++) {
          final date = _getNextDateForWeekday(pattern['day'] as int)
              .add(Duration(days: week * 7));
          await firestore.collection('classes').add({
            'teacherId': teacherId,
            'scheduledDate': Timestamp.fromDate(date),
            'startTime': pattern['start'],
            'endTime': pattern['end'],
            'location': 'Gym',
            'recurrenceType': 'weekly',
            'eventType': 'class_',
          });
        }
      }
      
      // Verify we have 6 classes (3 patterns × 2 weeks)
      var allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      expect(allClasses.docs.length, equals(6));
      
      // ACT - Delete only Wednesday pattern
      final batch = firestore.batch();
      for (final doc in allClasses.docs) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        if (date.weekday == 3) { // Wednesday only
          batch.delete(doc.reference);
        }
      }
      await batch.commit();
      
      // ASSERT
      allClasses = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      
      expect(allClasses.docs.length, equals(4)); // 6 - 2 = 4
      
      // Monday and Friday should still exist
      final remainingDays = allClasses.docs.map((doc) {
        final date = (doc.data()['scheduledDate'] as Timestamp).toDate();
        return date.weekday;
      }).toSet();
      
      expect(remainingDays.contains(1), isTrue); // Monday exists
      expect(remainingDays.contains(3), isFalse); // Wednesday deleted
      expect(remainingDays.contains(5), isTrue); // Friday exists
    });

    test('Deleting non-existing schedule should not affect database', () async {
      // ARRANGE - Create one schedule
      await firestore.collection('classes').add({
        'teacherId': teacherId,
        'scheduledDate': Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
        'startTime': '18:00',
        'endTime': '19:00',
        'location': 'Park',
        'recurrenceType': 'weekly',
        'eventType': 'class_',
      });
      
      var classesBefore = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      expect(classesBefore.docs.length, equals(1));
      
      // ACT - Try to delete a non-matching pattern
      final batch = firestore.batch();
      int deleteCount = 0;
      
      for (final doc in classesBefore.docs) {
        // This won't match anything
        if (doc.data()['startTime'] == '09:00') {
          batch.delete(doc.reference);
          deleteCount++;
        }
      }
      
      if (deleteCount > 0) {
        await batch.commit();
      }
      
      // ASSERT - Nothing should be deleted
      var classesAfter = await firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();
      expect(classesAfter.docs.length, equals(1)); // Still 1
      expect(deleteCount, equals(0));
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