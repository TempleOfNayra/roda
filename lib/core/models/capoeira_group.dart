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
  final String createdBy; // Teacher who created it
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
    required this.createdBy,
    required this.createdAt,
    this.isActive = true,
  });
  
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
      createdBy: data['createdBy'] ?? '',
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
      'createdBy': createdBy,
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