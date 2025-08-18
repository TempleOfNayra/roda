import 'package:equatable/equatable.dart';

enum UserRole { teacher, student }

class UserModel extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final String capoeiraName;
  final DateTime dateOfBirth;
  final UserRole role;
  final List<String> teachingGroupIds; // Groups this teacher teaches for
  final List<String> joinedGroupIds; // Groups user has joined as member
  final String? affiliationGroupId; // Student's affiliated group (future feature)
  final String? groupId; // Legacy - to be removed
  final String? groupName; // Legacy - to be removed
  final String? teacherName; // For students - their teacher's name
  final String? profilePictureUrl; // Profile picture URL from R2
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.capoeiraName,
    required this.dateOfBirth,
    required this.role,
    this.teachingGroupIds = const [],
    this.joinedGroupIds = const [],
    this.affiliationGroupId,
    this.groupId,
    this.groupName,
    this.teacherName,
    this.profilePictureUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      fullName: map['fullName'] ?? '',
      capoeiraName: map['capoeiraName'] ?? '',
      dateOfBirth: DateTime.parse(map['dateOfBirth']),
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.student,
      ),
      teachingGroupIds: List<String>.from(map['teachingGroupIds'] ?? []),
      joinedGroupIds: List<String>.from(map['joinedGroupIds'] ?? []),
      affiliationGroupId: map['affiliationGroupId'],
      groupId: map['groupId'],
      groupName: map['groupName'],
      teacherName: map['teacherName'],
      profilePictureUrl: map['profilePictureUrl'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'capoeiraName': capoeiraName,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'role': role.name,
      'teachingGroupIds': teachingGroupIds,
      'joinedGroupIds': joinedGroupIds,
      'affiliationGroupId': affiliationGroupId,
      'groupId': groupId,
      'groupName': groupName,
      'teacherName': teacherName,
      'profilePictureUrl': profilePictureUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? capoeiraName,
    DateTime? dateOfBirth,
    UserRole? role,
    List<String>? teachingGroupIds,
    List<String>? joinedGroupIds,
    String? affiliationGroupId,
    String? groupId,
    String? groupName,
    String? teacherName,
    String? profilePictureUrl,
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
      teachingGroupIds: teachingGroupIds ?? this.teachingGroupIds,
      joinedGroupIds: joinedGroupIds ?? this.joinedGroupIds,
      affiliationGroupId: affiliationGroupId ?? this.affiliationGroupId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      teacherName: teacherName ?? this.teacherName,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
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
        teachingGroupIds,
        joinedGroupIds,
        affiliationGroupId,
        groupId,
        groupName,
        teacherName,
        profilePictureUrl,
        createdAt,
        updatedAt,
      ];
}