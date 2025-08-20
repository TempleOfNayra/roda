
enum CapoeiraStyle {
  angola,
  regional,
  contemporanea,
  other;
  
  String get displayName {
    switch (this) {
      case CapoeiraStyle.angola:
        return 'Angola';
      case CapoeiraStyle.regional:
        return 'Regional';
      case CapoeiraStyle.contemporanea:
        return 'Contemporânea';
      case CapoeiraStyle.other:
        return 'Other';
    }
  }
}

class CapoeiraGroup {
  final String id;
  final String name; // Main group name (e.g., "ABADA")
  final String? branch; // Branch/location (e.g., "SF", "Oakland")
  final String displayName; // Full display (e.g., "ABADA SF")
  final String? description;
  final String city; // City where group is located
  final String? locationAddress; // Full address from Google Places
  final String? locationName; // Location name from Google Places
  final double? latitude; // Latitude for map display
  final double? longitude; // Longitude for map display
  final String? placeId; // Google Places ID
  final String teacherTitle; // Teacher title (e.g., "Mestre", "Professor", "Instrutor")
  final String teacherFullName; // Teacher's full name
  final CapoeiraStyle capoeiraStyle; // Angola, Regional, Contemporânea, Other
  final String? lineage; // Lineage/linhagem (e.g., "Mestre Bimba", "Mestre Pastinha")
  final String? venmoHandle; // Venmo handle for payments (without @)
  final List<String> adminIds; // Admins of this group
  final List<String> teacherIds; // Teachers in this group
  final List<String> memberIds; // All members of the group
  final String createdBy; // Teacher who created it
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
    required this.city,
    this.locationAddress,
    this.locationName,
    this.latitude,
    this.longitude,
    this.placeId,
    required this.teacherTitle,
    required this.teacherFullName,
    required this.capoeiraStyle,
    this.lineage,
    this.venmoHandle,
    List<String>? adminIds,
    required this.teacherIds,
    List<String>? memberIds,
    required this.createdBy,
    this.teacherProfilePicture,
    this.headerImageUrl,
    List<GroupAnnouncement>? announcements,
    required this.createdAt,
    this.isActive = true,
  }) : adminIds = adminIds ?? [createdBy], // Creator is automatically admin
       memberIds = memberIds ?? [createdBy], // Creator is automatically member
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
      city: map['city'] ?? map['location'] ?? 'Unknown City',  // Fallback to location field
      locationAddress: map['location_address'],
      locationName: map['location_name'],
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
      placeId: map['place_id'],
      teacherTitle: map['teacher_title'] ?? 'Professor',
      teacherFullName: map['teacher_full_name'] ?? 'Unknown Teacher',
      capoeiraStyle: map['capoeira_style'] != null 
        ? CapoeiraStyle.values.firstWhere(
            (e) => e.name == map['capoeira_style'],
            orElse: () => CapoeiraStyle.other,
          )
        : CapoeiraStyle.contemporanea,
      lineage: map['lineage'],
      venmoHandle: map['venmo_handle'],
      teacherIds: List<String>.from(map['teacher_ids'] ?? []),
      memberIds: List<String>.from(map['member_ids'] ?? []),
      createdBy: map['created_by'] ?? '',
      teacherProfilePicture: map['teacher_profile_picture'],
      headerImageUrl: map['header_image_url'],
      createdAt: DateTime.parse(map['created_at']),
      isActive: map['is_active'] ?? true,
    );
  }
  
  // Alias for fromMap to match repository pattern
  factory CapoeiraGroup.fromJson(Map<String, dynamic> json) => CapoeiraGroup.fromMap(json);
  
  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'branch': branch,
      'display_name': displayName,
      'description': description,
      'city': city,
      'location_address': locationAddress,
      'location_name': locationName,
      'latitude': latitude,
      'longitude': longitude,
      'place_id': placeId,
      'teacher_title': teacherTitle,
      'teacher_full_name': teacherFullName,
      'capoeira_style': capoeiraStyle.name,
      'lineage': lineage,
      'venmo_handle': venmoHandle,
      'admin_ids': adminIds,
      'teacher_ids': teacherIds,
      'member_ids': memberIds,
      'created_by': createdBy,
      'teacher_profile_picture': teacherProfilePicture,
      'header_image_url': headerImageUrl,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
    };
  }
  
  // Alias for toJson
  Map<String, dynamic> toMap() => toJson();
  
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