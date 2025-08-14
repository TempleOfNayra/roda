import 'package:cloud_firestore/cloud_firestore.dart';

/// Cleans ONLY schedule-related data, preserves users and groups
Future<void> cleanupScheduleData() async {
  final db = FirebaseFirestore.instance;
  
  print('🧹 CLEANING SCHEDULE DATA ONLY (preserving users/groups)');
  
  try {
    // 1. Delete ALL schedule templates
    print('\n1. Deleting schedule_templates...');
    final templates = await db.collection('schedule_templates').get();
    final templateBatch = db.batch();
    for (final doc in templates.docs) {
      templateBatch.delete(doc.reference);
    }
    if (templates.docs.isNotEmpty) {
      await templateBatch.commit();
      print('   ✓ Deleted ${templates.docs.length} templates');
    } else {
      print('   ✓ No templates to delete');
    }
    
    // 2. Delete ALL class instances
    print('\n2. Deleting class_instances...');
    final instances = await db.collection('class_instances').get();
    final instanceBatch = db.batch();
    for (final doc in instances.docs) {
      instanceBatch.delete(doc.reference);
    }
    if (instances.docs.isNotEmpty) {
      await instanceBatch.commit();
      print('   ✓ Deleted ${instances.docs.length} instances');
    } else {
      print('   ✓ No instances to delete');
    }
    
    // 3. Delete OLD classes collection (if exists)
    print('\n3. Deleting old classes collection...');
    final oldClasses = await db.collection('classes').get();
    final classBatch = db.batch();
    for (final doc in oldClasses.docs) {
      classBatch.delete(doc.reference);
    }
    if (oldClasses.docs.isNotEmpty) {
      await classBatch.commit();
      print('   ✓ Deleted ${oldClasses.docs.length} old classes');
    } else {
      print('   ✓ No old classes to delete');
    }
    
    // 4. Delete attendance records (optional - comment out if you want to keep)
    print('\n4. Deleting attendance records...');
    final attendance = await db.collection('attendance').get();
    final attendanceBatch = db.batch();
    for (final doc in attendance.docs) {
      attendanceBatch.delete(doc.reference);
    }
    if (attendance.docs.isNotEmpty) {
      await attendanceBatch.commit();
      print('   ✓ Deleted ${attendance.docs.length} attendance records');
    } else {
      print('   ✓ No attendance records to delete');
    }
    
    print('\n✅ CLEANUP COMPLETE - Schedule data cleared');
    print('✅ Users and groups preserved');
    
  } catch (e) {
    print('❌ CLEANUP FAILED: $e');
    rethrow;
  }
}