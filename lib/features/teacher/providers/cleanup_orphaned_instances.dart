import 'package:cloud_firestore/cloud_firestore.dart';

/// Deletes all class instances that belong to inactive or non-existent templates
Future<void> cleanupOrphanedInstances() async {
  final db = FirebaseFirestore.instance;
  
  print('🧹 Starting cleanup of orphaned instances...');
  
  // Get all active template IDs
  final activeTemplates = await db
      .collection('schedule_templates')
      .where('isActive', isEqualTo: true)
      .get();
  
  final activeTemplateIds = activeTemplates.docs.map((doc) => doc.id).toSet();
  print('Found ${activeTemplateIds.length} active templates');
  
  // Get all instances
  final allInstances = await db.collection('class_instances').get();
  print('Found ${allInstances.docs.length} total instances');
  
  // Find orphaned instances
  final batch = db.batch();
  int orphanCount = 0;
  
  for (final doc in allInstances.docs) {
    final templateId = doc.data()['templateId'] as String?;
    
    if (templateId == null || !activeTemplateIds.contains(templateId)) {
      // This instance is orphaned
      batch.delete(doc.reference);
      orphanCount++;
      print('  - Deleting orphaned instance: ${doc.id} (template: $templateId)');
    }
  }
  
  if (orphanCount > 0) {
    await batch.commit();
    print('✅ Deleted $orphanCount orphaned instances');
  } else {
    print('✅ No orphaned instances found');
  }
}