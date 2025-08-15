import 'package:cloud_firestore/cloud_firestore.dart';

enum ClassStatus {
  scheduled,
  completed,
  cancelled,
}

enum PaymentStatus {
  unpaid,
  confirmed,
  verified, // For future: when teacher manually verifies
}

class PaymentConfirmation {
  final PaymentStatus status;
  final DateTime? confirmedAt;
  final String? paymentMethod; // 'venmo', 'cash', etc.
  
  PaymentConfirmation({
    required this.status,
    this.confirmedAt,
    this.paymentMethod,
  });
  
  factory PaymentConfirmation.fromMap(Map<String, dynamic> map) {
    return PaymentConfirmation(
      status: PaymentStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => PaymentStatus.unpaid,
      ),
      confirmedAt: map['confirmedAt'] != null 
          ? (map['confirmedAt'] as Timestamp).toDate()
          : null,
      paymentMethod: map['paymentMethod'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
    };
  }
}

class ClassInstance {
  final String id;
  final String templateId; // This is THE key - links to schedule_templates
  final DateTime scheduledDate; // The specific date this instance occurs
  final ClassStatus status;
  final List<String> attendingStudentIds;
  final List<String> presentStudentIds;
  final Map<String, PaymentConfirmation> paymentConfirmations; // userId -> payment confirmation
  final String? notes; // Instance-specific notes
  
  ClassInstance({
    required this.id,
    required this.templateId,
    required this.scheduledDate,
    this.status = ClassStatus.scheduled,
    List<String>? attendingStudentIds,
    List<String>? presentStudentIds,
    Map<String, PaymentConfirmation>? paymentConfirmations,
    this.notes,
  }) : attendingStudentIds = attendingStudentIds ?? [],
       presentStudentIds = presentStudentIds ?? [],
       paymentConfirmations = paymentConfirmations ?? {};
  
  factory ClassInstance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse payment confirmations
    final paymentConfirmations = <String, PaymentConfirmation>{};
    if (data['paymentConfirmations'] != null) {
      final confirmationsMap = data['paymentConfirmations'] as Map<String, dynamic>;
      confirmationsMap.forEach((userId, confirmationData) {
        if (confirmationData is Map<String, dynamic>) {
          paymentConfirmations[userId] = PaymentConfirmation.fromMap(confirmationData);
        }
      });
    }
    
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
      paymentConfirmations: paymentConfirmations,
      notes: data['notes'],
    );
  }
  
  Map<String, dynamic> toFirestore() {
    // Convert payment confirmations to map
    final confirmationsMap = <String, dynamic>{};
    paymentConfirmations.forEach((userId, confirmation) {
      confirmationsMap[userId] = confirmation.toMap();
    });
    
    return {
      'templateId': templateId,
      'scheduledDate': Timestamp.fromDate(scheduledDate),
      'status': status.name,
      'attendingStudentIds': attendingStudentIds,
      'presentStudentIds': presentStudentIds,
      if (confirmationsMap.isNotEmpty) 'paymentConfirmations': confirmationsMap,
      if (notes != null) 'notes': notes,
    };
  }
}