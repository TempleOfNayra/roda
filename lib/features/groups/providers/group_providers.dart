import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/capoeira_group.dart';

// Provider for all active groups
final allGroupsProvider = StreamProvider<List<CapoeiraGroup>>((ref) {
  try {
    return FirebaseFirestore.instance
        .collection('capoeira_groups')
        .where('isActive', isEqualTo: true)
        .orderBy('displayName')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CapoeiraGroup.fromFirestore(doc))
            .toList())
        .handleError((error) {
          print('Error fetching groups: $error');
          return [];
        });
  } catch (e) {
    print('Error setting up groups stream: $e');
    return Stream.value([]);
  }
});

// Provider for a specific group
final groupByIdProvider = FutureProvider.family<CapoeiraGroup?, String>((ref, groupId) async {
  final doc = await FirebaseFirestore.instance
      .collection('capoeira_groups')
      .doc(groupId)
      .get();
  
  if (!doc.exists) return null;
  return CapoeiraGroup.fromFirestore(doc);
});

// Provider for groups that a teacher teaches for
final teacherGroupsProvider = FutureProvider.family<List<CapoeiraGroup>, List<String>>(
  (ref, groupIds) async {
    if (groupIds.isEmpty) return [];
    
    final groups = <CapoeiraGroup>[];
    for (final groupId in groupIds) {
      final doc = await FirebaseFirestore.instance
          .collection('capoeira_groups')
          .doc(groupId)
          .get();
      
      if (doc.exists) {
        groups.add(CapoeiraGroup.fromFirestore(doc));
      }
    }
    
    return groups;
  },
);

// Service for group operations
class GroupService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Create a new group
  Future<String> createGroup({
    required String name,
    String? branch,
    String? description,
    String? location,
    String? venmoHandle,
    required String createdBy,
  }) async {
    // Check if group with same name and branch exists
    final displayName = CapoeiraGroup.createDisplayName(name, branch);
    
    final existing = await _db
        .collection('capoeira_groups')
        .where('displayName', isEqualTo: displayName)
        .where('isActive', isEqualTo: true)
        .get();
    
    if (existing.docs.isNotEmpty) {
      throw Exception('A group with this name already exists');
    }
    
    final group = CapoeiraGroup(
      id: '',
      name: name,
      branch: branch,
      displayName: displayName,
      description: description,
      location: location,
      venmoHandle: venmoHandle,
      teacherIds: [createdBy],
      createdBy: createdBy,
      createdAt: DateTime.now(),
      isActive: true,
    );
    
    final docRef = await _db.collection('capoeira_groups').add(group.toFirestore());
    return docRef.id;
  }
  
  // Add a teacher to a group
  Future<void> addTeacherToGroup(String groupId, String teacherId) async {
    await _db.collection('capoeira_groups').doc(groupId).update({
      'teacherIds': FieldValue.arrayUnion([teacherId]),
    });
  }
  
  // Remove a teacher from a group
  Future<void> removeTeacherFromGroup(String groupId, String teacherId) async {
    await _db.collection('capoeira_groups').doc(groupId).update({
      'teacherIds': FieldValue.arrayRemove([teacherId]),
    });
  }
}

final groupServiceProvider = Provider((ref) => GroupService());