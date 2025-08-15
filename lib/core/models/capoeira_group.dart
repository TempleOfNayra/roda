import 'package:cloud_firestore/cloud_firestore.dart';

class CapoeiraGroup {
  final String id;
  final String name; // Main group name (e.g., "ABADA")
  final String? branch; // Branch/location (e.g., "SF", "Oakland")
  final String displayName; // Full display (e.g., "ABADA SF")
  final String? description;
  final String? location; // General location/city
  final String? venmoHandle; // Venmo handle for payments (without @)
  final List<String> teacherIds; // Teachers in this group
  final List<String> memberIds; // All members of the group
  final String createdBy; // Teacher who created it
  final String? teacherName; // Name of the teacher who created it
  final String? teacherProfilePicture; // Teacher's profile picture URL
  final String? headerImageUrl; // Group header image URL
  final List<GroupAnnouncement> announcements; // Group announcements
  final DateTime createdAt;
  final bool isActive;
  
  CapoeiraGroup({
    required this.id,
    required this.name,
    this.branch,
    required this.displayName,
    this.description,
    this.location,
    this.venmoHandle,
    required this.teacherIds,
    List<String>? memberIds,
    required this.createdBy,
    this.teacherName,
    this.teacherProfilePicture,
    this.headerImageUrl,
    List<GroupAnnouncement>? announcements,
    required this.createdAt,
    this.isActive = true,
  }) : memberIds = memberIds ?? [],
       announcements = announcements ?? [];
  
  factory CapoeiraGroup.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CapoeiraGroup(
      id: doc.id,
      name: data['name'] ?? '',
      branch: data['branch'],
      displayName: data['displayName'] ?? '',
      description: data['description'],
      location: data['location'],
      venmoHandle: data['venmoHandle'],
      teacherIds: List<String>.from(data['teacherIds'] ?? []),
      memberIds: List<String>.from(data['memberIds'] ?? []),
      createdBy: data['createdBy'] ?? '',
      teacherName: data['teacherName'],
      teacherProfilePicture: data['teacherProfilePicture'],
      headerImageUrl: data['headerImageUrl'],
      announcements: (data['announcements'] as List<dynamic>?)
          ?.map((a) => GroupAnnouncement.fromMap(a))
          .toList() ?? [],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }
  
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'branch': branch,
      'displayName': displayName,
      'description': description,
      'location': location,
      'venmoHandle': venmoHandle,
      'teacherIds': teacherIds,
      'memberIds': memberIds,
      'createdBy': createdBy,
      'teacherName': teacherName,
      'teacherProfilePicture': teacherProfilePicture,
      'headerImageUrl': headerImageUrl,
      'announcements': announcements.map((a) => a.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
  
  // Helper to create display name
  static String createDisplayName(String name, String? branch) {
    if (branch != null && branch.isNotEmpty) {
      return '$name $branch';
    }
    return name;
  }
}

class GroupAnnouncement {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final String? authorName;
  final DateTime createdAt;
  final bool isPinned;
  
  GroupAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    this.authorName,
    required this.createdAt,
    this.isPinned = false,
  });
  
  factory GroupAnnouncement.fromMap(Map<String, dynamic> map) {
    return GroupAnnouncement(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      isPinned: map['isPinned'] ?? false,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPinned': isPinned,
    };
  }
}