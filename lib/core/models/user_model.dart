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

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      capoeiraName: json['capoeira_name'] ?? '',
      dateOfBirth: json['date_of_birth'] != null 
        ? DateTime.parse(json['date_of_birth'])
        : DateTime(1990, 1, 1), // Default date if null
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.student,
      ),
      teachingGroupIds: json['teaching_group_ids'] != null
        ? List<String>.from(json['teaching_group_ids'])
        : [],
      joinedGroupIds: json['joined_group_ids'] != null
        ? List<String>.from(json['joined_group_ids'])
        : [],
      affiliationGroupId: json['affiliation_group_id'],
      groupId: json['group_id'],
      groupName: json['group_name'],
      teacherName: json['teacher_name'],
      profilePictureUrl: json['profile_picture_url'],
      createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now(),
      updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'])
        : DateTime.now(),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'capoeira_name': capoeiraName,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'role': role.name,
      'teaching_group_ids': teachingGroupIds,
      'joined_group_ids': joinedGroupIds,
      'affiliation_group_id': affiliationGroupId,
      'group_id': groupId,
      'group_name': groupName,
      'teacher_name': teacherName,
      'profile_picture_url': profilePictureUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
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