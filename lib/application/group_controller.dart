import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/data/repositories/group_repository.dart';
import 'package:roda/data/repositories/user_repository.dart';
import 'package:roda/data/repositories/auth_repository.dart';
import 'package:roda/data/core/db_exceptions.dart' as app_exceptions;
import 'package:roda/core/utils/logger.dart';
import 'package:uuid/uuid.dart';

final groupControllerProvider = Provider<GroupController>((ref) {
  return GroupController(ref);
});

final userGroupsProvider = StreamProvider<List<CapoeiraGroup>>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  final currentUser = authRepository.currentUser;
  
  if (currentUser == null) {
    return Stream.value([]);
  }
  
  final groupRepository = ref.watch(groupRepositoryProvider);
  return groupRepository.getUserGroupsStream(currentUser.id);
});

final groupMembersProvider = FutureProvider.family<List<UserModel>, String>((ref, groupId) async {
  final userRepository = ref.watch(userRepositoryProvider);
  return userRepository.getUsersByGroup(groupId);
});

final searchGroupsProvider = FutureProvider.family<List<CapoeiraGroup>, String>((ref, searchTerm) async {
  final groupRepository = ref.watch(groupRepositoryProvider);
  return groupRepository.searchGroups(searchTerm: searchTerm);
});

class GroupController {
  final Ref _ref;
  
  GroupController(this._ref);
  
  GroupRepository get _groupRepository => _ref.read(groupRepositoryProvider);
  UserRepository get _userRepository => _ref.read(userRepositoryProvider);
  AuthRepository get _authRepository => _ref.read(authRepositoryProvider);
  
  Future<CapoeiraGroup> createGroupWithDetails({
    required String name,
    String? branch,
    required String city,
    String? locationAddress,
    String? locationName,
    double? latitude,
    double? longitude,
    String? placeId,
    required String teacherTitle,
    required String teacherFullName,
    required CapoeiraStyle capoeiraStyle,
    String? lineage,
    String? description,
    String? venmoHandle,
    String? headerImageUrl,
    String? logoImageUrl,
    String? contactNumber,
    String? email,
  }) async {
    try {
      Logger.debug('Creating new group with details: $name $branch');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      final userProfile = await _userRepository.getUser(currentUser.id);
      if (userProfile == null) {
        throw app_exceptions.NotFoundException('User profile not found');
      }
      
      if (userProfile.role != UserRole.teacher) {
        throw app_exceptions.PermissionException('Only teachers can create groups');
      }
      
      final displayName = CapoeiraGroup.createDisplayName(name, branch);
      
      final existingGroup = await _groupRepository.getGroupByDisplayName(displayName);
      if (existingGroup != null) {
        throw app_exceptions.ValidationException('A group with this name already exists');
      }
      
      final group = CapoeiraGroup(
        id: const Uuid().v4(),
        name: name,
        branch: branch,
        displayName: displayName,
        description: description,
        city: city,
        locationAddress: locationAddress,
        locationName: locationName,
        latitude: latitude,
        longitude: longitude,
        placeId: placeId,
        teacherTitle: teacherTitle,
        teacherFullName: teacherFullName,
        capoeiraStyle: capoeiraStyle,
        lineage: lineage,
        venmoHandle: venmoHandle,
        teacherIds: [currentUser.id],
        adminIds: [currentUser.id],
        memberIds: [currentUser.id],
        createdBy: currentUser.id,
        teacherProfilePicture: userProfile.profilePictureUrl,
        headerImageUrl: headerImageUrl,
        logoImageUrl: logoImageUrl,
        contactNumber: contactNumber,
        email: email,
        createdAt: DateTime.now(),
      );
      
      final createdGroup = await _groupRepository.createGroup(group);
      Logger.debug('Group created successfully: ${createdGroup.id}');
      
      return createdGroup;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Create Group Error: ${appException.message}');
      throw appException;
    }
  }
  
  // Legacy method for backward compatibility
  Future<CapoeiraGroup> createGroup({
    required String name,
    String? branch,
    String? description,
    String? location,
    String? venmoHandle,
  }) async {
    try {
      Logger.debug('Creating new group: $name $branch');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      final userProfile = await _userRepository.getUser(currentUser.id);
      if (userProfile == null) {
        throw app_exceptions.NotFoundException('User profile not found');
      }
      
      if (userProfile.role != UserRole.teacher) {
        throw app_exceptions.PermissionException('Only teachers can create groups');
      }
      
      final displayName = CapoeiraGroup.createDisplayName(name, branch);
      
      final existingGroup = await _groupRepository.getGroupByDisplayName(displayName);
      if (existingGroup != null) {
        throw app_exceptions.ValidationException('A group with this name already exists');
      }
      
      final group = CapoeiraGroup(
        id: const Uuid().v4(),
        name: name,
        branch: branch,
        displayName: displayName,
        description: description,
        city: location ?? 'Unknown',
        teacherTitle: 'Professor',
        teacherFullName: userProfile.fullName,
        capoeiraStyle: CapoeiraStyle.contemporanea,
        lineage: null,
        venmoHandle: venmoHandle,
        teacherIds: [currentUser.id],
        adminIds: [currentUser.id],
        createdBy: currentUser.id,
        teacherProfilePicture: userProfile.profilePictureUrl,
        headerImageUrl: null,
        createdAt: DateTime.now(),
      );
      
      final createdGroup = await _groupRepository.createGroup(group);
      Logger.debug('Group created successfully: ${createdGroup.id}');
      
      return createdGroup;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Create Group Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<CapoeiraGroup> updateGroup(CapoeiraGroup group) async {
    try {
      Logger.debug('Updating group: ${group.id}');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      if (!group.adminIds.contains(currentUser.id) && group.createdBy != currentUser.id) {
        throw app_exceptions.PermissionException('You do not have permission to update this group');
      }
      
      final updatedGroup = await _groupRepository.updateGroup(group);
      Logger.debug('Group updated successfully');
      
      return updatedGroup;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Update Group Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> deleteGroup(String groupId) async {
    try {
      Logger.debug('Deleting group: $groupId');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      final group = await _groupRepository.getGroup(groupId);
      if (group == null) {
        throw app_exceptions.NotFoundException('Group not found');
      }
      
      if (group.createdBy != currentUser.id) {
        throw app_exceptions.PermissionException('Only the group creator can delete the group');
      }
      
      await _groupRepository.deleteGroup(groupId);
      Logger.debug('Group deleted successfully');
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Delete Group Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> joinGroup(String groupId) async {
    try {
      Logger.debug('Joining group: $groupId');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      await _groupRepository.addMemberToGroup(groupId, currentUser.id);
      Logger.debug('Successfully joined group');
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Join Group Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> leaveGroup(String groupId) async {
    try {
      Logger.debug('Leaving group: $groupId');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      await _groupRepository.removeMemberFromGroup(groupId, currentUser.id);
      Logger.debug('Successfully left group');
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Leave Group Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> addTeacher(String groupId, String teacherId) async {
    try {
      Logger.debug('Adding teacher $teacherId to group $groupId');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      final group = await _groupRepository.getGroup(groupId);
      if (group == null) {
        throw app_exceptions.NotFoundException('Group not found');
      }
      
      if (!group.adminIds.contains(currentUser.id) && group.createdBy != currentUser.id) {
        throw app_exceptions.PermissionException('You do not have permission to add teachers to this group');
      }
      
      final teacher = await _userRepository.getUser(teacherId);
      if (teacher == null) {
        throw app_exceptions.NotFoundException('Teacher not found');
      }
      
      if (teacher.role != UserRole.teacher) {
        throw app_exceptions.ValidationException('User is not a teacher');
      }
      
      await _groupRepository.addTeacherToGroup(groupId, teacherId);
      Logger.debug('Teacher added successfully');
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Add Teacher Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> removeTeacher(String groupId, String teacherId) async {
    try {
      Logger.debug('Removing teacher $teacherId from group $groupId');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      final group = await _groupRepository.getGroup(groupId);
      if (group == null) {
        throw app_exceptions.NotFoundException('Group not found');
      }
      
      if (!group.adminIds.contains(currentUser.id) && group.createdBy != currentUser.id) {
        throw app_exceptions.PermissionException('You do not have permission to remove teachers from this group');
      }
      
      if (group.createdBy == teacherId) {
        throw app_exceptions.ValidationException('Cannot remove the group creator');
      }
      
      await _groupRepository.removeTeacherFromGroup(groupId, teacherId);
      Logger.debug('Teacher removed successfully');
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Remove Teacher Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<List<CapoeiraGroup>> searchGroups({
    String? searchTerm,
    String? location,
  }) async {
    try {
      Logger.debug('Searching groups: term=$searchTerm, location=$location');
      
      final groups = await _groupRepository.searchGroups(
        searchTerm: searchTerm,
        location: location,
      );
      
      Logger.debug('Found ${groups.length} groups');
      return groups;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Search Groups Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<List<UserModel>> getGroupMembers(String groupId) async {
    try {
      Logger.debug('Getting members for group: $groupId');
      
      final members = await _userRepository.getUsersByGroup(groupId);
      
      Logger.debug('Found ${members.length} members');
      return members;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Get Group Members Error: ${appException.message}');
      throw appException;
    }
  }
}