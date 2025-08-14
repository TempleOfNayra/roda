import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  class_,
  roda,
}

enum RecurrenceType {
  oneTime,
  daily,
  weekly,
  biweekly,
  monthly,
}

class ScheduleTemplate {
  final String id;
  final String teacherId;
  final String groupId;
  final String groupName;
  final EventType eventType;
  final RecurrenceType recurrenceType;
  final int? dayOfWeek; // 1-7 (Monday-Sunday) - null for one-time events
  final DateTime? oneTimeDate; // Specific date for one-time events
  final String startTime; // HH:MM
  final String endTime; // HH:MM
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final bool isActive;
  
  ScheduleTemplate({
    required this.id,
    required this.teacherId,
    required this.groupId,
    required this.groupName,
    required this.eventType,
    required this.recurrenceType,
    this.dayOfWeek,
    this.oneTimeDate,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.isActive = true,
  });
  
  factory ScheduleTemplate.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ScheduleTemplate(
      id: doc.id,
      teacherId: data['teacherId'],
      groupId: data['groupId'],
      groupName: data['groupName'],
      eventType: data['eventType'] == 'roda' ? EventType.roda : EventType.class_,
      recurrenceType: RecurrenceType.values.firstWhere(
        (r) => r.name == data['recurrenceType'],
        orElse: () => RecurrenceType.weekly,
      ),
      dayOfWeek: data['dayOfWeek'],
      oneTimeDate: data['oneTimeDate'] != null 
          ? (data['oneTimeDate'] as Timestamp).toDate() 
          : null,
      startTime: data['startTime'],
      endTime: data['endTime'],
      location: data['location'],
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'teacherId': teacherId,
      'groupId': groupId,
      'groupName': groupName,
      'eventType': eventType == EventType.roda ? 'roda' : 'class_',
      'recurrenceType': recurrenceType.name,
      if (dayOfWeek != null) 'dayOfWeek': dayOfWeek,
      if (oneTimeDate != null) 'oneTimeDate': Timestamp.fromDate(oneTimeDate!),
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
  
  String get dayName {
    if (dayOfWeek == null) return '';
    switch (dayOfWeek) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
  
  String get recurrenceLabel {
    switch (recurrenceType) {
      case RecurrenceType.oneTime: return 'One Time';
      case RecurrenceType.daily: return 'Daily';
      case RecurrenceType.weekly: return 'Weekly';
      case RecurrenceType.biweekly: return 'Biweekly';
      case RecurrenceType.monthly: return 'Monthly';
    }
  }
}