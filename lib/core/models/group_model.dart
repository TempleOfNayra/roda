import 'package:equatable/equatable.dart';

class GroupModel extends Equatable {
  final String id;
  final String name;
  final String teacherId;
  final String teacherName;
  final List<ClassSchedule> schedule;
  final Location location;
  final PaymentPreference paymentPreference;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.teacherId,
    required this.teacherName,
    required this.schedule,
    required this.location,
    required this.paymentPreference,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String id) {
    return GroupModel(
      id: id,
      name: map['name'] ?? '',
      teacherId: map['teacherId'] ?? '',
      teacherName: map['teacherName'] ?? '',
      schedule: (map['schedule'] as List<dynamic>?)
              ?.map((s) => ClassSchedule.fromMap(s))
              .toList() ??
          [],
      location: Location.fromMap(map['location'] ?? {}),
      paymentPreference: PaymentPreference.fromMap(map['paymentPreference'] ?? {}),
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'schedule': schedule.map((s) => s.toMap()).toList(),
      'location': location.toMap(),
      'paymentPreference': paymentPreference.toMap(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        teacherId,
        teacherName,
        schedule,
        location,
        paymentPreference,
        createdAt,
        updatedAt,
      ];
}

class ClassSchedule extends Equatable {
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final String startTime; // HH:mm format
  final String endTime; // HH:mm format

  const ClassSchedule({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory ClassSchedule.fromMap(Map<String, dynamic> map) {
    return ClassSchedule(
      dayOfWeek: map['dayOfWeek'] ?? 1,
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  @override
  List<Object?> get props => [dayOfWeek, startTime, endTime];
}

class Location extends Equatable {
  final double latitude;
  final double longitude;
  final String address;
  final String? placeName;

  const Location({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.placeName,
  });

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? '',
      placeName: map['placeName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'placeName': placeName,
    };
  }

  @override
  List<Object?> get props => [latitude, longitude, address, placeName];
}

class PaymentPreference extends Equatable {
  final bool acceptsVenmo;
  final bool acceptsPayPal;
  final bool acceptsZelle;
  final bool acceptsHonorSystem;
  final String? venmoHandle;
  final String? payPalEmail;
  final String? zelleInfo;

  const PaymentPreference({
    required this.acceptsVenmo,
    required this.acceptsPayPal,
    required this.acceptsZelle,
    required this.acceptsHonorSystem,
    this.venmoHandle,
    this.payPalEmail,
    this.zelleInfo,
  });

  factory PaymentPreference.fromMap(Map<String, dynamic> map) {
    return PaymentPreference(
      acceptsVenmo: map['acceptsVenmo'] ?? false,
      acceptsPayPal: map['acceptsPayPal'] ?? false,
      acceptsZelle: map['acceptsZelle'] ?? false,
      acceptsHonorSystem: map['acceptsHonorSystem'] ?? true,
      venmoHandle: map['venmoHandle'],
      payPalEmail: map['payPalEmail'],
      zelleInfo: map['zelleInfo'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'acceptsVenmo': acceptsVenmo,
      'acceptsPayPal': acceptsPayPal,
      'acceptsZelle': acceptsZelle,
      'acceptsHonorSystem': acceptsHonorSystem,
      'venmoHandle': venmoHandle,
      'payPalEmail': payPalEmail,
      'zelleInfo': zelleInfo,
    };
  }

  @override
  List<Object?> get props => [
        acceptsVenmo,
        acceptsPayPal,
        acceptsZelle,
        acceptsHonorSystem,
        venmoHandle,
        payPalEmail,
        zelleInfo,
      ];
}