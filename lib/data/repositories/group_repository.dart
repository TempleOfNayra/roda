import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/data/core/base_repository.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/utils/logger.dart';

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository(ref);
});

class GroupRepository extends BaseRepository {
  GroupRepository(super.ref);
  
  SupabaseClient get _client => ref.read(supabaseClientProvider);
  
  Future<CapoeiraGroup?> getGroup(String groupId) async {
    return executeWithNullableResult(
      () async {
        Logger.debug('Fetching group with ID: $groupId');
        
        final response = await _client
            .from('groups')
            .select()
            .eq('id', groupId)
            .maybeSingle();
        
        if (response == null) {
          Logger.debug('No group found with ID: $groupId');
          return null;
        }
        
        return CapoeiraGroup.fromJson(response);
      },
      operationName: 'Get Group',
    );
  }
  
  Future<CapoeiraGroup?> getGroupByDisplayName(String displayName) async {
    return executeWithNullableResult(
      () async {
        Logger.debug('Fetching group with display name: $displayName');
        
        final response = await _client
            .from('groups')
            .select()
            .eq('display_name', displayName)
            .maybeSingle();
        
        if (response == null) {
          Logger.debug('No group found with display name: $displayName');
          return null;
        }
        
        return CapoeiraGroup.fromJson(response);
      },
      operationName: 'Get Group By Display Name',
    );
  }
  
  Future<CapoeiraGroup> createGroup(CapoeiraGroup group) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Creating group: ${group.displayName}');
        
        final data = group.toJson();
        data['created_at'] = DateTime.now().toIso8601String();
        
        final response = await _client
            .from('groups')
            .insert(data)
            .select()
            .single();
        
        Logger.debug('Group created successfully');
        return CapoeiraGroup.fromJson(response);
      },
      operationName: 'Create Group',
    );
  }
  
  Future<CapoeiraGroup> updateGroup(CapoeiraGroup group) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Updating group with ID: ${group.id}');
        
        final data = group.toJson();
        data.remove('created_at');
        data.remove('created_by');
        
        final response = await _client
            .from('groups')
            .update(data)
            .eq('id', group.id)
            .select()
            .single();
        
        Logger.debug('Group updated successfully');
        return CapoeiraGroup.fromJson(response);
      },
      operationName: 'Update Group',
    );
  }
  
  Future<void> deleteGroup(String groupId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Deleting group with ID: $groupId');
        
        await _client
            .from('groups')
            .delete()
            .eq('id', groupId);
        
        Logger.debug('Group deleted successfully');
      },
      operationName: 'Delete Group',
    );
  }
  
  Future<List<CapoeiraGroup>> getUserGroups(String userId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Fetching groups for user: $userId');
        
        final response = await _client
            .from('groups')
            .select()
            .or('created_by.eq.$userId,teacher_ids.cs.{$userId},member_ids.cs.{$userId}')
            .order('created_at', ascending: false);
        
        final groups = response.map<CapoeiraGroup>((data) {
          return CapoeiraGroup.fromJson(data);
        }).toList();
        
        Logger.debug('Found ${groups.length} groups for user');
        return groups;
      },
      operationName: 'Get User Groups',
    );
  }
  
  Future<List<CapoeiraGroup>> searchGroups({
    String? searchTerm,
    String? location,
    int limit = 20,
    int offset = 0,
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Searching groups with term: $searchTerm, location: $location');
        
        var query = _client.from('groups').select().eq('is_active', true);
        
        if (searchTerm != null && searchTerm.isNotEmpty) {
          query = query.or(
            'name.ilike.%$searchTerm%,branch.ilike.%$searchTerm%,display_name.ilike.%$searchTerm%'
          );
        }
        
        if (location != null && location.isNotEmpty) {
          query = query.ilike('location', '%$location%');
        }
        
        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        
        final groups = response.map<CapoeiraGroup>((data) {
          return CapoeiraGroup.fromJson(data);
        }).toList();
        
        Logger.debug('Search returned ${groups.length} groups');
        return groups;
      },
      operationName: 'Search Groups',
    );
  }
  
  Future<void> addMemberToGroup(String groupId, String userId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Adding user $userId to group $groupId');
        
        await _client.from('group_members').upsert({
          'group_id': groupId,
          'user_id': userId,
          'joined_at': DateTime.now().toIso8601String(),
        }, onConflict: 'group_id,user_id');
        
        Logger.debug('Member added successfully');
      },
      operationName: 'Add Member To Group',
    );
  }
  
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Removing user $userId from group $groupId');
        
        await _client
            .from('group_members')
            .delete()
            .match({'group_id': groupId, 'user_id': userId});
        
        Logger.debug('Member removed successfully');
      },
      operationName: 'Remove Member From Group',
    );
  }
  
  Future<void> addTeacherToGroup(String groupId, String teacherId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Adding teacher $teacherId to group $groupId');
        
        final group = await getGroup(groupId);
        if (group == null) {
          throw NotFoundException('Group not found');
        }
        
        final teacherIds = [...group.teacherIds];
        if (!teacherIds.contains(teacherId)) {
          teacherIds.add(teacherId);
        }
        
        await _client
            .from('groups')
            .update({'teacher_ids': teacherIds})
            .eq('id', groupId);
        
        Logger.debug('Teacher added successfully');
      },
      operationName: 'Add Teacher To Group',
    );
  }
  
  Future<void> removeTeacherFromGroup(String groupId, String teacherId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Removing teacher $teacherId from group $groupId');
        
        final group = await getGroup(groupId);
        if (group == null) {
          throw NotFoundException('Group not found');
        }
        
        final teacherIds = [...group.teacherIds];
        teacherIds.remove(teacherId);
        
        await _client
            .from('groups')
            .update({'teacher_ids': teacherIds})
            .eq('id', groupId);
        
        Logger.debug('Teacher removed successfully');
      },
      operationName: 'Remove Teacher From Group',
    );
  }
  
  Stream<List<CapoeiraGroup>> getUserGroupsStream(String userId) {
    return executeStream(
      () {
        Logger.debug('Setting up group stream for user: $userId');
        
        return _client
            .from('groups')
            .stream(primaryKey: ['id'])
            .order('created_at')
            .map((data) {
              // Filter in memory since stream doesn't support 'or' operator
              final filteredData = data.where((item) {
                final createdBy = item['created_by'] == userId;
                final teacherIds = (item['teacher_ids'] as List?)?.contains(userId) ?? false;
                final memberIds = (item['member_ids'] as List?)?.contains(userId) ?? false;
                return createdBy || teacherIds || memberIds;
              }).toList();
              
              return filteredData.map<CapoeiraGroup>((item) {
                return CapoeiraGroup.fromJson(item);
              }).toList();
            });
      },
      operationName: 'User Groups Stream',
    );
  }
}