import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/data/core/base_repository.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/utils/logger.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref);
});

class UserRepository extends BaseRepository {
  UserRepository(super.ref);
  
  SupabaseClient get _client => ref.read(supabaseClientProvider);
  
  Future<UserModel?> getUser(String userId) async {
    return executeWithNullableResult(
      () async {
        Logger.debug('Fetching user with ID: $userId');
        
        final response = await _client
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();
        
        if (response == null) {
          Logger.debug('No user found with ID: $userId');
          return null;
        }
        
        return UserModel.fromJson(response);
      },
      operationName: 'Get User',
    );
  }
  
  Future<UserModel> createUser(UserModel user) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Creating user with ID: ${user.id}');
        
        final data = user.toJson();
        data['created_at'] = DateTime.now().toIso8601String();
        data['updated_at'] = DateTime.now().toIso8601String();
        
        final response = await _client
            .from('users')
            .insert(data)
            .select()
            .single();
        
        Logger.debug('User created successfully');
        return UserModel.fromJson(response);
      },
      operationName: 'Create User',
    );
  }
  
  Future<UserModel> updateUser(UserModel user) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Updating user with ID: ${user.id}');
        
        final data = user.toJson();
        data['updated_at'] = DateTime.now().toIso8601String();
        data.remove('created_at');
        
        final response = await _client
            .from('users')
            .update(data)
            .eq('id', user.id)
            .select()
            .single();
        
        Logger.debug('User updated successfully');
        return UserModel.fromJson(response);
      },
      operationName: 'Update User',
    );
  }
  
  Future<void> deleteUser(String userId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Deleting user with ID: $userId');
        
        await _client
            .from('users')
            .delete()
            .eq('id', userId);
        
        Logger.debug('User deleted successfully');
      },
      operationName: 'Delete User',
    );
  }
  
  Stream<UserModel?> getUserStream(String userId) {
    Logger.debug('Setting up user stream for ID: $userId');
    
    try {
      return _client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', userId)
          .map((data) {
            if (data.isEmpty) {
              Logger.debug('No user data in stream for ID: $userId');
              return null;
            }
            
            final userData = data.first;
            Logger.debug('User stream data received');
            return UserModel.fromJson(userData);
          })
          .handleError((error, stack) {
            Logger.debug('User stream error: $error');
            Logger.debug('Stack trace: $stack');
            // Don't throw error, let stream continue with last known state
          });
    } catch (e) {
      Logger.debug('Failed to setup realtime stream, falling back to single fetch: $e');
      // Fallback to a simple stream that emits the current user data
      return Stream.fromFuture(getUser(userId));
    }
  }
  
  Future<List<UserModel>> getUsersByGroup(String groupId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Fetching users for group: $groupId');
        
        final response = await _client
            .from('group_members')
            .select('user_id, users!inner(*)')
            .eq('group_id', groupId);
        
        final users = response.map<UserModel>((item) {
          final userData = item['users'] as Map<String, dynamic>;
          return UserModel.fromJson(userData);
        }).toList();
        
        Logger.debug('Found ${users.length} users in group');
        return users;
      },
      operationName: 'Get Users By Group',
    );
  }
  
  Future<List<UserModel>> searchUsers({
    String? searchTerm,
    UserRole? role,
    int limit = 20,
    int offset = 0,
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Searching users with term: $searchTerm, role: $role');
        
        var query = _client.from('users').select();
        
        if (searchTerm != null && searchTerm.isNotEmpty) {
          query = query.or(
            'full_name.ilike.%$searchTerm%,capoeira_name.ilike.%$searchTerm%,email.ilike.%$searchTerm%'
          );
        }
        
        if (role != null) {
          query = query.eq('role', role.name);
        }
        
        final response = await query
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1);
        
        final users = response.map<UserModel>((data) {
          return UserModel.fromJson(data);
        }).toList();
        
        Logger.debug('Search returned ${users.length} users');
        return users;
      },
      operationName: 'Search Users',
    );
  }
  
  Future<bool> checkEmailExists(String email) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Checking if email exists: $email');
        
        final response = await _client
            .from('users')
            .select('id')
            .eq('email', email)
            .maybeSingle();
        
        final exists = response != null;
        Logger.debug('Email exists: $exists');
        return exists;
      },
      operationName: 'Check Email Exists',
    );
  }
  
  Future<void> addGroupToUser({
    required String userId,
    required String groupId,
    bool isTeacher = false,
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Adding group $groupId to user $userId (isTeacher: $isTeacher)');
        
        final user = await getUser(userId);
        if (user == null) {
          throw NotFoundException('User not found');
        }
        
        final joinedGroupIds = [...user.joinedGroupIds];
        if (!joinedGroupIds.contains(groupId)) {
          joinedGroupIds.add(groupId);
        }
        
        final teachingGroupIds = [...user.teachingGroupIds];
        if (isTeacher && !teachingGroupIds.contains(groupId)) {
          teachingGroupIds.add(groupId);
        }
        
        await _client
            .from('users')
            .update({
              'joined_group_ids': joinedGroupIds,
              'teaching_group_ids': teachingGroupIds,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', userId);
        
        Logger.debug('Group added to user successfully');
      },
      operationName: 'Add Group To User',
    );
  }
  
  Future<void> removeGroupFromAllUsers(String groupId) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Removing group $groupId from all users');
        
        // Get all users who have this group in their joined or teaching groups
        final response = await _client
            .from('users')
            .select()
            .or('joined_group_ids.cs.{$groupId},teaching_group_ids.cs.{$groupId}');
        
        final users = (response as List).map((data) => UserModel.fromJson(data)).toList();
        
        // Update each user to remove the group
        for (final user in users) {
          final joinedGroupIds = user.joinedGroupIds.where((id) => id != groupId).toList();
          final teachingGroupIds = user.teachingGroupIds.where((id) => id != groupId).toList();
          
          await _client
              .from('users')
              .update({
                'joined_group_ids': joinedGroupIds,
                'teaching_group_ids': teachingGroupIds,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', user.id);
        }
        
        Logger.debug('Group removed from ${users.length} users');
      },
      operationName: 'Remove Group From All Users',
    );
  }
}