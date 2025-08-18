
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
  final String teacherName; // Display name of the teacher
  final String groupId; // The capoeira group ID
  final String groupName; // Display name of the group (e.g., "ABADA SF")
  final EventType eventType;
  final RecurrenceType recurrenceType;
  final int? dayOfWeek; // 1-7 (Monday-Sunday) - null for one-time events
  final DateTime? oneTimeDate; // Specific date for one-time events
  final String startTime; // HH:MM
  final String endTime; // HH:MM
  final String location;
  final double? latitude;
  final double? longitude;
  final double? price; // Price in USD
  final DateTime createdAt;
  final bool isActive;
  
  ScheduleTemplate({
    required this.id,
    required this.teacherId,
    required this.teacherName,
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
    this.price,
    required this.createdAt,
    this.isActive = true,
  });
  
  
  
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