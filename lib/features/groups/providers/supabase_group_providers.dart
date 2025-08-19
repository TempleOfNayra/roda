import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/application/group_controller.dart';
import 'package:roda/data/repositories/group_repository.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/utils/logger.dart';

// Re-export providers from group_controller for backward compatibility
export 'package:roda/application/group_controller.dart' show userGroupsProvider, groupMembersProvider, searchGroupsProvider;

// Legacy provider - use groupControllerProvider instead
final supabaseGroupServiceProvider = Provider((ref) => SupabaseGroupService(ref));

// Legacy SupabaseGroupService - wraps new GroupController for backward compatibility
class SupabaseGroupService {
  final Ref _ref;
  
  SupabaseGroupService(this._ref);
  
  GroupController get _groupController => _ref.read(groupControllerProvider);
  GroupRepository get _groupRepository => _ref.read(groupRepositoryProvider);
  
  // Check if a group exists with the given name
  Future<CapoeiraGroup?> findExistingGroup(String name, String? branch) async {
    final displayName = CapoeiraGroup.createDisplayName(name, branch);
    return await _groupRepository.getGroupByDisplayName(displayName);
  }
  
  // Create a new group (legacy method - use createGroupWithDetails for new groups)
  Future<String> createGroup({
    required String name,
    required String city,
    String? branch,
    String? description,
    String? location,
    String? venmoHandle,
    required String createdBy,
    required String teacherName,
    String? teacherProfilePicture,
    String? profileHeaderUrl,
  }) async {
    try {
      final group = await _groupController.createGroupWithDetails(
        name: name,
        branch: branch,
        city: city,
        teacherTitle: 'Professor', // Default title for legacy calls
        teacherFullName: teacherName,
        capoeiraStyle: CapoeiraStyle.contemporanea, // Default style for legacy calls
        lineage: null,
        description: description,
        venmoHandle: venmoHandle,
        headerImageUrl: profileHeaderUrl,
      );
      return group.id;
    } catch (e) {
      Logger.debug('Error creating group: $e');
      rethrow;
    }
  }
  
  // Get group by ID
  Future<CapoeiraGroup?> getGroup(String groupId) async {
    return await _groupRepository.getGroup(groupId);
  }
  
  // Stream group data
  Stream<CapoeiraGroup?> getGroupStream(String groupId) {
    return _groupRepository.getGroup(groupId).asStream();
  }
  
  // Get all groups
  Stream<List<CapoeiraGroup>> getAllGroupsStream() {
    return _groupRepository.searchGroups().asStream();
  }
  
  // Get user's groups
  Future<List<CapoeiraGroup>> getUserGroups(String userId) async {
    return await _groupRepository.getUserGroups(userId);
  }
  
  // Add teacher to group
  Future<void> addTeacherToGroup(String groupId, String teacherId) async {
    await _groupController.addTeacher(groupId, teacherId);
  }
  
  // Add member to group
  Future<void> addMemberToGroup(String groupId, String memberId) async {
    await _groupRepository.addMemberToGroup(groupId, memberId);
  }
  
  // Get group by display name
  Future<CapoeiraGroup?> getGroupByDisplayName(String displayName) async {
    return await _groupRepository.getGroupByDisplayName(displayName);
  }
  
  // Get group creator info
  Future<Map<String, String>?> getGroupCreatorInfo(String groupName, String? branch) async {
    try {
      final displayName = CapoeiraGroup.createDisplayName(groupName, branch);
      final group = await _groupRepository.getGroupByDisplayName(displayName);
      
      if (group != null) {
        return {
          'id': group.createdBy,
          'name': group.teacherFullName,
        };
      }
      return null;
    } catch (e) {
      Logger.debug('Error getting group creator info: $e');
      return null;
    }
  }
  
  // Remove teacher from group
  Future<void> removeTeacherFromGroup(String groupId, String teacherId) async {
    await _groupController.removeTeacher(groupId, teacherId);
  }
  
  // Admin management methods
  Future<void> addAdminToGroup(String groupId, String userId) async {
    final group = await _groupRepository.getGroup(groupId);
    if (group != null) {
      final adminIds = [...group.adminIds];
      if (!adminIds.contains(userId)) {
        adminIds.add(userId);
        final updatedGroup = CapoeiraGroup(
          id: group.id,
          name: group.name,
          branch: group.branch,
          displayName: group.displayName,
          description: group.description,
          city: group.city,
          teacherTitle: group.teacherTitle,
          teacherFullName: group.teacherFullName,
          capoeiraStyle: group.capoeiraStyle,
          lineage: group.lineage,
          venmoHandle: group.venmoHandle,
          adminIds: adminIds,
          teacherIds: group.teacherIds,
          memberIds: group.memberIds,
          createdBy: group.createdBy,
          teacherProfilePicture: group.teacherProfilePicture,
          headerImageUrl: group.headerImageUrl,
          announcements: group.announcements,
          createdAt: group.createdAt,
          isActive: group.isActive,
        );
        await _groupRepository.updateGroup(updatedGroup);
      }
    }
  }
  
  Future<void> removeAdminFromGroup(String groupId, String userId) async {
    final group = await _groupRepository.getGroup(groupId);
    if (group != null) {
      final adminIds = [...group.adminIds];
      adminIds.remove(userId);
      final updatedGroup = CapoeiraGroup(
        id: group.id,
        name: group.name,
        branch: group.branch,
        displayName: group.displayName,
        description: group.description,
        city: group.city,
        teacherTitle: group.teacherTitle,
        teacherFullName: group.teacherFullName,
        capoeiraStyle: group.capoeiraStyle,
        lineage: group.lineage,
        venmoHandle: group.venmoHandle,
        adminIds: adminIds,
        teacherIds: group.teacherIds,
        memberIds: group.memberIds,
        createdBy: group.createdBy,
        teacherProfilePicture: group.teacherProfilePicture,
        headerImageUrl: group.headerImageUrl,
        announcements: group.announcements,
        createdAt: group.createdAt,
        isActive: group.isActive,
      );
      await _groupRepository.updateGroup(updatedGroup);
    }
  }
  
  // Check if user is admin
  Future<bool> isUserAdmin(String groupId, String userId) async {
    final group = await _groupRepository.getGroup(groupId);
    return group?.adminIds.contains(userId) ?? false;
  }
  
  // Remove member from group
  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    await _groupRepository.removeMemberFromGroup(groupId, memberId);
  }
  
  // Update group details
  Future<void> updateGroupDetails(String groupId, Map<String, dynamic> updates) async {
    final group = await _groupRepository.getGroup(groupId);
    if (group != null) {
      final updatedGroup = CapoeiraGroup(
        id: group.id,
        name: updates['name'] ?? group.name,
        branch: updates['branch'] ?? group.branch,
        displayName: updates['display_name'] ?? group.displayName,
        description: updates['description'] ?? group.description,
        city: updates['city'] ?? group.city,
        teacherTitle: updates['teacher_title'] ?? group.teacherTitle,
        teacherFullName: updates['teacher_full_name'] ?? group.teacherFullName,
        capoeiraStyle: updates['capoeira_style'] != null 
          ? CapoeiraStyle.values.firstWhere(
              (e) => e.name == updates['capoeira_style'],
              orElse: () => group.capoeiraStyle,
            )
          : group.capoeiraStyle,
        lineage: updates['lineage'] ?? group.lineage,
        venmoHandle: updates['venmo_handle'] ?? group.venmoHandle,
        adminIds: group.adminIds,
        teacherIds: group.teacherIds,
        memberIds: group.memberIds,
        createdBy: group.createdBy,
        teacherProfilePicture: group.teacherProfilePicture,
        headerImageUrl: updates['header_image_url'] ?? group.headerImageUrl,
        announcements: group.announcements,
        createdAt: group.createdAt,
        isActive: updates['is_active'] ?? group.isActive,
      );
      await _groupRepository.updateGroup(updatedGroup);
    }
  }
}

// Provider for getting group by ID with member info
final groupByIdProvider = StreamProvider.family<CapoeiraGroup?, String>((ref, groupId) {
  final repository = ref.watch(groupRepositoryProvider);
  return repository.getGroup(groupId).asStream();
});

// Provider for all groups
final allGroupsProvider = StreamProvider<List<CapoeiraGroup>>((ref) {
  final repository = ref.watch(groupRepositoryProvider);
  return repository.searchGroups().asStream();
});