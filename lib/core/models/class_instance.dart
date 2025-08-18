
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
          ? DateTime.parse(map['confirmedAt'])
          : null,
      paymentMethod: map['paymentMethod'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'status': status.name,
      if (confirmedAt != null) 'confirmedAt': confirmedAt!.toIso8601String(),
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
  
  
}