import 'package:cloud_firestore/cloud_firestore.dart';

enum ClassStatus {
  scheduled,
  completed,
  cancelled,
}

class ClassInstance {
  final String id;
  final String templateId; // This is THE key - links to schedule_templates
  final DateTime scheduledDate; // The specific date this instance occurs
  final ClassStatus status;
  final List<String> attendingStudentIds;
  final List<String> presentStudentIds;
  final String? notes; // Instance-specific notes
  
  ClassInstance({
    required this.id,
    required this.templateId,
    required this.scheduledDate,
    this.status = ClassStatus.scheduled,
    this.attendingStudentIds = const [],
    this.presentStudentIds = const [],
    this.notes,
  });
  
  factory ClassInstance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassInstance(
      id: doc.id,
      templateId: data['templateId'],
      scheduledDate: (data['scheduledDate'] as Timestamp).toDate(),
      status: ClassStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => ClassStatus.scheduled,
      ),
      attendingStudentIds: List<String>.from(data['attendingStudentIds'] ?? []),
      presentStudentIds: List<String>.from(data['presentStudentIds'] ?? []),
      notes: data['notes'],
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'templateId': templateId,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'attendingStudentIds': attendingStudentIds,
      'presentStudentIds': presentStudentIds,
      if (notes != null) 'notes': notes,
    };
  }
}