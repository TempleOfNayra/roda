
class CapoeiraGroup {
  final String id;
  final String name; // Main group name (e.g., "ABADA")
  final String? branch; // Branch/location (e.g., "SF", "Oakland")
  final String displayName; // Full display (e.g., "ABADA SF")
  final String? description;
  final String? location; // General location/city
  final String? venmoHandle; // Venmo handle for payments (without @)
  final List<String> adminIds; // Admins of this group
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
    List<String>? adminIds,
    required this.teacherIds,
    List<String>? memberIds,
    required this.createdBy,
    this.teacherName,
    this.teacherProfilePicture,
    this.headerImageUrl,
    List<GroupAnnouncement>? announcements,
    required this.createdAt,
    this.isActive = true,
  }) : adminIds = adminIds ?? [],
       memberIds = memberIds ?? [],
       announcements = announcements ?? [];
  
  
  
  // Factory constructor to create from map (Supabase)
  factory CapoeiraGroup.fromMap(Map<String, dynamic> map) {
    return CapoeiraGroup(
      id: map['id'],
      name: map['name'],
      branch: map['branch'],
      adminIds: List<String>.from(map['admin_ids'] ?? []),
      displayName: map['display_name'] ?? CapoeiraGroup.createDisplayName(map['name'], map['branch']),
      description: map['description'],
      venmoHandle: map['venmo_handle'],
      teacherIds: List<String>.from(map['teacher_ids'] ?? []),
      memberIds: List<String>.from(map['member_ids'] ?? []),
      createdBy: map['created_by'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] ?? true,
    );
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
      createdAt: DateTime.parse(map['createdAt']),
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
      'createdAt': createdAt.toIso8601String(),
      'isPinned': isPinned,
    };
  }
}