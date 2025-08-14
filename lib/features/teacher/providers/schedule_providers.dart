import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/models/class_instance.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

// Represents a full class with both template and instance data
class FullClassData {
  final ClassInstance instance;
  final ScheduleTemplate template;
  
  FullClassData({required this.instance, required this.template});
  
  // Convenience getters that pull from template
  String get location => template.location;
  String get startTime => template.startTime;
  String get endTime => template.endTime;
  EventType get eventType => template.eventType;
  double? get latitude => template.latitude;
  double? get longitude => template.longitude;
  String get groupName => template.groupName;
  String get teacherId => template.teacherId;
  
  // Instance-specific data
  DateTime get scheduledDate => instance.scheduledDate;
  ClassStatus get status => instance.status;
  List<String> get attendingStudentIds => instance.attendingStudentIds;
  List<String> get presentStudentIds => instance.presentStudentIds;
}

// Get all upcoming classes for a teacher (joins templates with instances)
final teacherUpcomingFullClassesProvider = FutureProvider.family<List<FullClassData>, String>(
  (ref, teacherId) async {
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));
      
      // First get all active templates for this teacher
      final templatesSnapshot = await db
          .collection('schedule_templates')
          .where('teacherId', isEqualTo: teacherId)
          .where('isActive', isEqualTo: true)
          .get();
    
    final templates = <String, ScheduleTemplate>{};
    for (final doc in templatesSnapshot.docs) {
      templates[doc.id] = ScheduleTemplate.fromFirestore(doc);
    }
    
    if (templates.isEmpty) return [];
    
    // Get instances for these templates
    final instancesSnapshot = await db
        .collection('class_instances')
        .where('templateId', whereIn: templates.keys.toList())
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('scheduledDate')
        .get();
    
    // Join instances with templates
    final fullClasses = <FullClassData>[];
    for (final doc in instancesSnapshot.docs) {
      final instance = ClassInstance.fromFirestore(doc);
      final template = templates[instance.templateId];
      
      if (template != null) {
        fullClasses.add(FullClassData(
          instance: instance,
          template: template,
        ));
      }
    }
    
    return fullClasses;
    } catch (e) {
      // Log the full error to console including any Firebase index creation links
      print('==================================');
      print('ERROR in teacherUpcomingFullClassesProvider:');
      print(e.toString());
      print('==================================');
      rethrow;
    }
  },
);

// Get all templates for the schedule page
final activeTemplatesProvider = StreamProvider<List<ScheduleTemplate>>((ref) {
  final user = ref.watch(currentUserProvider).value;
  if (user == null) return Stream.value([]);
  
  return FirebaseFirestore.instance
      .collection('schedule_templates')
      .where('teacherId', isEqualTo: user.id)
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ScheduleTemplate.fromFirestore(doc))
          .toList());
});

// Get upcoming classes/rodas that a user is registered for
final userRegisteredClassesProvider = FutureProvider.family<List<FullClassData>, String>(
  (ref, userId) async {
    try {
      final db = FirebaseFirestore.instance;
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 30));
      
      // Get all instances where user is in attendingStudentIds
      final instancesSnapshot = await db
          .collection('class_instances')
          .where('attendingStudentIds', arrayContains: userId)
          .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('scheduledDate')
          .get();
      
      if (instancesSnapshot.docs.isEmpty) return [];
      
      // Get unique template IDs
      final templateIds = instancesSnapshot.docs
          .map((doc) => doc.data()['templateId'] as String)
          .toSet()
          .toList();
      
      // Fetch templates
      final templates = <String, ScheduleTemplate>{};
      for (final templateId in templateIds) {
        final templateDoc = await db
            .collection('schedule_templates')
            .doc(templateId)
            .get();
        
        if (templateDoc.exists) {
          templates[templateId] = ScheduleTemplate.fromFirestore(templateDoc);
        }
      }
      
      // Join instances with templates
      final fullClasses = <FullClassData>[];
      for (final doc in instancesSnapshot.docs) {
        final instance = ClassInstance.fromFirestore(doc);
        final template = templates[instance.templateId];
        
        if (template != null) {
          fullClasses.add(FullClassData(
            instance: instance,
            template: template,
          ));
        }
      }
      
      return fullClasses;
    } catch (e) {
      print('Error fetching user registered classes: $e');
      rethrow;
    }
  },
);

// Get upcoming classes for the map (all teachers)
final mapUpcomingClassesProvider = FutureProvider<List<FullClassData>>((ref) async {
  try {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final endDate = now.add(const Duration(days: 30));
  
  // Get all active templates
  print('=== MAP DATA SOURCE DEBUG ===');
  print('Fetching from: schedule_templates (NEW architecture)');
  
  final templatesSnapshot = await db
      .collection('schedule_templates')
      .where('isActive', isEqualTo: true)
      .get();
  
  print('Found ${templatesSnapshot.docs.length} active templates');
  
  final templates = <String, ScheduleTemplate>{};
  for (final doc in templatesSnapshot.docs) {
    final template = ScheduleTemplate.fromFirestore(doc);
    templates[doc.id] = template;
    print('Template: ${template.location} - ${template.eventType} - ${template.recurrenceLabel}');
  }
  
  if (templates.isEmpty) {
    print('No templates found - returning empty list');
    return [];
  }
  
  // Get instances in batches (Firestore whereIn has a limit of 10)
  print('Fetching from: class_instances (NEW architecture)');
  
  final allInstances = <ClassInstance>[];
  final templateIds = templates.keys.toList();
  
  for (int i = 0; i < templateIds.length; i += 10) {
    final batch = templateIds.skip(i).take(10).toList();
    
    final instancesSnapshot = await db
        .collection('class_instances')
        .where('templateId', whereIn: batch)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('scheduledDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();
    
    print('Batch ${i ~/ 10 + 1}: Found ${instancesSnapshot.docs.length} instances');
    
    for (final doc in instancesSnapshot.docs) {
      allInstances.add(ClassInstance.fromFirestore(doc));
    }
  }
  
  print('Total instances found: ${allInstances.length}');
  print('=== END DEBUG ===');
  
  // Join instances with templates
  final fullClasses = <FullClassData>[];
  for (final instance in allInstances) {
    final template = templates[instance.templateId];
    
    if (template != null && template.isActive) {
      // Only include if template exists AND is active
      fullClasses.add(FullClassData(
        instance: instance,
        template: template,
      ));
    } else if (template == null) {
      print('⚠️ Orphaned instance found: ${instance.id} with templateId: ${instance.templateId}');
    }
  }
  
  // Sort by date
  fullClasses.sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  
  return fullClasses;
  } catch (e) {
    // Log the full error to console including any Firebase index creation links
    print('==================================');
    print('ERROR in mapUpcomingClassesProvider:');
    print(e.toString());
    print('==================================');
    rethrow;
  }
});