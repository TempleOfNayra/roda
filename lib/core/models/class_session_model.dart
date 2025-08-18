import 'package:equatable/equatable.dart';

class ClassSessionModel extends Equatable {
  final String id;
  final String groupId;
  final String groupName;
  final String teacherId;
  final EventType eventType;
  final DateTime scheduledDate;
  final String startTime;
  final String endTime;
  final String location;
  final double? latitude;
  final double? longitude;
  final RecurrenceType recurrenceType;
  final String? scheduleKey; // Key for linking recurring classes (e.g., "4-18:00-19:30")
  final String? patternId; // ID of the parent schedule pattern
  final List<String> attendingStudentIds;
  final List<String> presentStudentIds;
  final ClassStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClassSessionModel({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.teacherId,
    required this.eventType,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.latitude,
    this.longitude,
    required this.recurrenceType,
    this.scheduleKey,
    this.patternId,
    required this.attendingStudentIds,
    required this.presentStudentIds,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClassSessionModel.fromMap(Map<String, dynamic> map, String id) {
    return ClassSessionModel(
      id: id,
      groupId: map['groupId'] ?? '',
      groupName: map['groupName'] ?? '',
      teacherId: map['teacherId'] ?? '',
      eventType: EventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => EventType.class_,
      ),
      scheduledDate: DateTime.parse(map['scheduledDate']),
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      location: map['location'] ?? '',
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == map['recurrenceType'],
        orElse: () => RecurrenceType.none,
      ),
      scheduleKey: map['scheduleKey'],
      patternId: map['patternId'],
      attendingStudentIds: List<String>.from(map['attendingStudentIds'] ?? []),
      presentStudentIds: List<String>.from(map['presentStudentIds'] ?? []),
      status: ClassStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ClassStatus.scheduled,
      ),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'groupName': groupName,
      'teacherId': teacherId,
      'eventType': eventType.name,
      'scheduledDate': scheduledDate.toIso8601String(),
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'recurrenceType': recurrenceType.name,
      if (scheduleKey != null) 'scheduleKey': scheduleKey,
      if (patternId != null) 'patternId': patternId,
      'attendingStudentIds': attendingStudentIds,
      'presentStudentIds': presentStudentIds,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ClassSessionModel copyWith({
    String? id,
    String? groupId,
    String? groupName,
    String? teacherId,
    EventType? eventType,
    DateTime? scheduledDate,
    String? startTime,
    String? endTime,
    String? location,
    double? latitude,
    double? longitude,
    RecurrenceType? recurrenceType,
    String? scheduleKey,
    String? patternId,
    List<String>? attendingStudentIds,
    List<String>? presentStudentIds,
    ClassStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClassSessionModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      teacherId: teacherId ?? this.teacherId,
      eventType: eventType ?? this.eventType,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      scheduleKey: scheduleKey ?? this.scheduleKey,
      patternId: patternId ?? this.patternId,
      attendingStudentIds: attendingStudentIds ?? this.attendingStudentIds,
      presentStudentIds: presentStudentIds ?? this.presentStudentIds,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        groupId,
        groupName,
        teacherId,
        eventType,
        scheduledDate,
        startTime,
        endTime,
        location,
        latitude,
        longitude,
        recurrenceType,
        patternId,
        attendingStudentIds,
        presentStudentIds,
        status,
        createdAt,
        updatedAt,
      ];
}

enum ClassStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
}

enum EventType {
  class_,  // Regular training class
  roda,    // Roda event
}

enum RecurrenceType {
  none,     // One-time event
  weekly,   // Every week
  monthly,  // Every month
}