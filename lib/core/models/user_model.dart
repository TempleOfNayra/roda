import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { teacher, student }

class UserModel extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String capoeiraName;
  final DateTime dateOfBirth;
  final UserRole role;
  final String? groupId;
  final String? groupName;
  final String? teacherName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.capoeiraName,
    required this.dateOfBirth,
    required this.role,
    this.groupId,
    this.groupName,
    this.teacherName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      capoeiraName: map['capoeiraName'] ?? '',
      dateOfBirth: (map['dateOfBirth'] as Timestamp).toDate(),
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.student,
      ),
      groupId: map['groupId'],
      groupName: map['groupName'],
      teacherName: map['teacherName'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'capoeiraName': capoeiraName,
      'dateOfBirth': Timestamp.fromDate(dateOfBirth),
      'role': role.name,
      'groupId': groupId,
      'groupName': groupName,
      'teacherName': teacherName,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? capoeiraName,
    DateTime? dateOfBirth,
    UserRole? role,
    String? groupId,
    String? groupName,
    String? teacherName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      capoeiraName: capoeiraName ?? this.capoeiraName,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      role: role ?? this.role,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      teacherName: teacherName ?? this.teacherName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        email,
        fullName,
        capoeiraName,
        dateOfBirth,
        role,
        groupId,
        groupName,
        teacherName,
        createdAt,
        updatedAt,
      ];
}