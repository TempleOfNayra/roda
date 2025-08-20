// import 'package:flutter_riverpod/flutter_riverpod.dart'; // Unused - removed by DCM
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/core/utils/logger.dart';

// Unused - removed by DCM
// final supabaseUserRepositoryProvider = Provider<SupabaseUserRepository>((ref) {
//   return SupabaseUserRepository();
// });

class SupabaseUserRepository {
  final _client = SupabaseConfig.client;
  
  // Create a new user in Supabase
  Future<void> createUser(UserModel user) async {
    try {
      Logger.debug('Creating user in Supabase with ID: ${user.id}');
      await _client
          .from('users')
          .insert({
            'id': user.id, // Using Supabase Auth UID
            'email': user.email,
            'full_name': user.fullName,
            'capoeira_name': user.capoeiraName,
            'date_of_birth': user.dateOfBirth.toIso8601String(),
            'role': user.role.name,
            'profile_picture_url': user.profilePictureUrl,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
      Logger.debug('User created successfully in Supabase');
    } catch (e) {
      Logger.debug('Error creating user: $e');
      throw Exception('Failed to create user in Supabase: $e');
    }
  }
  
  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      Logger.debug('Fetching user from Supabase with ID: $userId');
      final response = await _client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      Logger.debug('User fetch response: $response');
      if (response == null) {
        Logger.debug('No user found with ID: $userId');
        return null;
      }
      
      return UserModel(
        id: response['id'],
        email: response['email'],
        fullName: response['full_name'],
        capoeiraName: response['capoeira_name'],
        dateOfBirth: DateTime.parse(response['date_of_birth']),
        role: UserRole.values.firstWhere(
          (e) => e.name == response['role'],
        ),
        profilePictureUrl: response['profile_picture_url'],
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
      );
    } catch (e) {
      Logger.debug('Error fetching user: $e');
      throw Exception('Failed to get user from Supabase: $e');
    }
  }
  
  // Update user
  Future<void> updateUser(UserModel user) async {
    try {
      await _client
          .from('users')
          .update({
            'email': user.email,
            'full_name': user.fullName,
            'capoeira_name': user.capoeiraName,
            'date_of_birth': user.dateOfBirth.toIso8601String(),
            'role': user.role.name,
            'profile_picture_url': user.profilePictureUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
    } catch (e) {
      throw Exception('Failed to update user in Supabase: $e');
    }
  }
  
  // Delete user
  Future<void> deleteUser(String userId) async {
    try {
      await _client
          .from('users')
          .delete()
          .eq('id', userId);
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
  
  // Stream user data
  Stream<UserModel?> getUserStream(String userId) {
    Logger.debug('Setting up user stream for ID: $userId');
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .handleError((error) {
          Logger.debug('User stream error handled: $error');
          // Return null on error to prevent app crash
          return null;
        })
        .map((data) {
          Logger.debug('User stream data received');
          if (data.isEmpty) {
            Logger.debug('No user data in stream for ID: $userId');
            return null;
          }
          final user = data.first;
          return UserModel(
            id: user['id'],
            email: user['email'],
            fullName: user['full_name'],
            capoeiraName: user['capoeira_name'],
            dateOfBirth: DateTime.parse(user['date_of_birth']),
            role: UserRole.values.firstWhere(
              (e) => e.name == user['role'],
            ),
            profilePictureUrl: user['profile_picture_url'],
            createdAt: DateTime.parse(user['created_at']),
            updatedAt: DateTime.parse(user['updated_at']),
          );
        });
  }
  
  // Get users by group
  Future<List<UserModel>> getUsersByGroup(String groupId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('user_id, users!inner(*)')
          .eq('group_id', groupId);
      
      return response.map<UserModel>((item) {
        final user = item['users'];
        return UserModel(
          id: user['id'],
          email: user['email'],
          fullName: user['full_name'],
          capoeiraName: user['capoeira_name'],
          dateOfBirth: DateTime.parse(user['date_of_birth']),
          role: UserRole.values.firstWhere(
            (e) => e.name == user['role'],
          ),
          profilePictureUrl: user['profile_picture_url'],
          createdAt: DateTime.parse(user['created_at']),
          updatedAt: DateTime.parse(user['updated_at']),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to get users by group: $e');
    }
  }
}