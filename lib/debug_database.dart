import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> debugDatabase() async {
  final db = FirebaseFirestore.instance;
  
  print('========== DATABASE DEBUG ==========');
  
  // Check schedule_templates collection
  print('\n1. SCHEDULE_TEMPLATES collection:');
  final templates = await db.collection('schedule_templates').get();
  print('   Total documents: ${templates.docs.length}');
  for (final doc in templates.docs) {
    final data = doc.data();
    print('   - ${data['location']} | ${data['eventType']} | Active: ${data['isActive']}');
  }
  
  // Check class_instances collection
  print('\n2. CLASS_INSTANCES collection:');
  final instances = await db.collection('class_instances').get();
  print('   Total documents: ${instances.docs.length}');
  if (instances.docs.isNotEmpty) {
    print('   First 5 instances:');
    for (final doc in instances.docs.take(5)) {
      final data = doc.data();
      final date = (data['scheduledDate'] as Timestamp).toDate();
      print('   - Template: ${data['templateId']} | Date: $date');
    }
  }
  
  // Check OLD classes collection
  print('\n3. CLASSES collection (OLD):');
  final oldClasses = await db.collection('classes').get();
  print('   Total documents: ${oldClasses.docs.length}');
  if (oldClasses.docs.isNotEmpty) {
    print('   First 5 classes:');
    for (final doc in oldClasses.docs.take(5)) {
      final data = doc.data();
      print('   - ${data['location']} | ${data['eventType']} | Teacher: ${data['teacherId']}');
    }
  }
  
  // Check events collection
  print('\n4. EVENTS collection:');
  final events = await db.collection('events').get();
  print('   Total documents: ${events.docs.length}');
  for (final doc in events.docs) {
    final data = doc.data();
    print('   - Document ID: ${doc.id}');
    print('     Data: ${data.toString()}');
  }
  
  // Check any other collections
  print('\n5. Checking for other collections...');
  // Note: Firestore doesn't have a direct API to list all collections
  // but we can check common names
  final collectionNames = ['groups', 'users', 'attendance', 'rodas'];
  for (final name in collectionNames) {
    final coll = await db.collection(name).limit(1).get();
    if (coll.docs.isNotEmpty) {
      final count = await db.collection(name).count().get();
      print('   - $name: ${count.count} documents');
    }
  }
  
  print('\n========== END DEBUG ==========');
}

// Call this function from somewhere in your app
void runDebug() async {
  await debugDatabase();
}