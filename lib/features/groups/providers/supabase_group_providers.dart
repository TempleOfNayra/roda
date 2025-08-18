import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

final supabaseGroupServiceProvider = Provider((ref) => SupabaseGroupService());

class SupabaseGroupService {
  final _client = SupabaseConfig.client;
  
  // Check if a group exists with the given name
  Future<CapoeiraGroup?> findExistingGroup(String name, String? branch) async {
    final displayName = CapoeiraGroup.createDisplayName(name, branch);
    
    try {
      final response = await _client
          .from('groups')
          .select()
          .eq('display_name', displayName)
          .eq('is_active', true)
          .maybeSingle();
      
      if (response == null) return null;
      
      return _mapToGroup(response);
    } catch (e) {
      print('Error finding existing group: $e');
      return null;
    }
  }
  
  // Create a new group
  Future<String> createGroup({
    required String name,
    String? branch,
    String? description,
    String? location,
    String? venmoHandle,
    required String createdBy,
    String? teacherName,
    String? teacherProfilePicture,
  }) async {
    // Check if group already exists
    final existingGroup = await findExistingGroup(name, branch);
    if (existingGroup != null) {
      throw Exception('Group ${existingGroup.displayName} already exists');
    }
    
    final displayName = CapoeiraGroup.createDisplayName(name, branch);
    
    try {
      // Create the group
      final groupResponse = await _client
          .from('groups')
          .insert({
            'name': name,
            'branch': branch,
            'display_name': displayName,
            'description': description,
            'location': location,
            'venmo_handle': venmoHandle,
            'created_by': createdBy,
          })
          .select()
          .single();
      
      final groupId = groupResponse['id'];
      
      // Add creator as admin and member
      await _client
          .from('group_members')
          .insert({
            'group_id': groupId,
            'user_id': createdBy,
            'role': 'admin',
          });
      
      return groupId;
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }
  
  // Get group by ID
  Future<CapoeiraGroup?> getGroup(String groupId) async {
    try {
      final response = await _client
          .from('groups')
          .select()
          .eq('id', groupId)
          .maybeSingle();
      
      if (response == null) return null;
      
      return _mapToGroup(response);
    } catch (e) {
      print('Error getting group: $e');
      return null;
    }
  }
  
  // Stream group data
  Stream<CapoeiraGroup?> getGroupStream(String groupId) {
    return _client
        .from('groups')
        .stream(primaryKey: ['id'])
        .eq('id', groupId)
        .map((data) {
          if (data.isEmpty) return null;
          return _mapToGroup(data.first);
        });
  }
  
  // Get all groups
  Stream<List<CapoeiraGroup>> getAllGroupsStream() {
    return _client
        .from('groups')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at')
        .map((data) => data.map((group) => _mapToGroup(group)).toList());
  }
  
  // Get user's groups
  Future<List<CapoeiraGroup>> getUserGroups(String userId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('groups!inner(*)')
          .eq('user_id', userId);
      
      return response.map<CapoeiraGroup>((item) => 
        _mapToGroup(item['groups'])
      ).toList();
    } catch (e) {
      print('Error getting user groups: $e');
      return [];
    }
  }
  
  // Add teacher to group
  Future<void> addTeacherToGroup(String groupId, String teacherId) async {
    try {
      final response = await _client
          .from('groups')
          .select('teacher_ids')
          .eq('id', groupId)
          .single();
      
      List<String> teacherIds = List<String>.from(response['teacher_ids'] ?? []);
      if (!teacherIds.contains(teacherId)) {
        teacherIds.add(teacherId);
        
        await _client
            .from('groups')
            .update({'teacher_ids': teacherIds})
            .eq('id', groupId);
      }
    } catch (e) {
      throw Exception('Failed to add teacher to group: $e');
    }
  }
  
  // Add member to group
  Future<void> addMemberToGroup(String groupId, String memberId) async {
    try {
      final response = await _client
          .from('groups')
          .select('member_ids')
          .eq('id', groupId)
          .single();
      
      List<String> memberIds = List<String>.from(response['member_ids'] ?? []);
      if (!memberIds.contains(memberId)) {
        memberIds.add(memberId);
        
        await _client
            .from('groups')
            .update({'member_ids': memberIds})
            .eq('id', groupId);
      }
    } catch (e) {
      throw Exception('Failed to add member to group: $e');
    }
  }
  
  // Get group by display name
  Future<CapoeiraGroup?> getGroupByDisplayName(String displayName) async {
    try {
      final response = await _client
          .from('groups')
          .select()
          .eq('display_name', displayName)
          .eq('is_active', true)
          .maybeSingle();
      
      if (response == null) return null;
      return _mapToGroup(response);
    } catch (e) {
      print('Error getting group by display name: $e');
      return null;
    }
  }
  
  // Get group creator info
  Future<Map<String, String>?> getGroupCreatorInfo(String groupName, String? branch) async {
    try {
      final displayName = CapoeiraGroup.createDisplayName(groupName, branch);
      final response = await _client
          .from('groups')
          .select('created_by, users!groups_created_by_fkey(full_name)')
          .eq('display_name', displayName)
          .eq('is_active', true)
          .maybeSingle();
      
      if (response != null) {
        return {
          'id': response['created_by'],
          'name': response['users']['full_name'] ?? 'Unknown Teacher',
        };
      }
      return null;
    } catch (e) {
      print('Error getting group creator info: $e');
      return null;
    }
  }
  
  
  // Remove teacher from group
  Future<void> removeTeacherFromGroup(String groupId, String teacherId) async {
    try {
      await _client
          .from('group_members')
          .update({'role': 'member'})
          .eq('group_id', groupId)
          .eq('user_id', teacherId);
    } catch (e) {
      throw Exception('Failed to remove teacher from group: $e');
    }
  }
  
  // Admin management methods
  Future<void> addAdminToGroup(String groupId, String userId) async {
    try {
      await _client
          .from('group_members')
          .update({'role': 'admin'})
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to add admin to group: $e');
    }
  }
  
  Future<void> removeAdminFromGroup(String groupId, String userId) async {
    try {
      await _client
          .from('group_members')
          .update({'role': 'member'})
          .eq('group_id', groupId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to remove admin from group: $e');
    }
  }
  
  // Check if user is admin
  Future<bool> isUserAdmin(String groupId, String userId) async {
    try {
      final response = await _client
          .from('group_members')
          .select('role')
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .maybeSingle();
      
      return response?['role'] == 'admin';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
  
  // Remove member from group
  Future<void> removeMemberFromGroup(String groupId, String memberId) async {
    try {
      await _client
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('user_id', memberId);
    } catch (e) {
      throw Exception('Failed to remove member from group: $e');
    }
  }
  
  // Update group details
  Future<void> updateGroupDetails(String groupId, Map<String, dynamic> updates) async {
    try {
      await _client
          .from('groups')
          .update(updates)
          .eq('id', groupId);
    } catch (e) {
      throw Exception('Failed to update group details: $e');
    }
  }
  
  // Helper to map database response to CapoeiraGroup model
  CapoeiraGroup _mapToGroup(Map<String, dynamic> data) {
    // Get member IDs
    final memberIds = <String>[];
    final teacherIds = <String>[];
    final adminIds = <String>[];
    
    // Note: You might need to fetch these separately or join them
    // For now, returning empty lists
    
    return CapoeiraGroup(
      id: data['id'],
      name: data['name'] ?? '',
      branch: data['branch'],
      displayName: data['display_name'] ?? '',
      description: data['description'],
      location: data['location'],
      venmoHandle: data['venmo_handle'],
      adminIds: adminIds,
      teacherIds: teacherIds,
      memberIds: memberIds,
      createdBy: data['created_by'] ?? '',
      teacherName: null, // Will need to join with users table
      teacherProfilePicture: null,
      headerImageUrl: data['header_image_url'],
      announcements: [],
      createdAt: DateTime.parse(data['created_at']),
      isActive: data['is_active'] ?? true,
    );
  }
}

// Provider for getting group by ID with member info
final groupByIdProvider = StreamProvider.family<CapoeiraGroup?, String>((ref, groupId) {
  final service = ref.watch(supabaseGroupServiceProvider);
  return service.getGroupStream(groupId);
});

// Provider for all groups
final allGroupsProvider = StreamProvider<List<CapoeiraGroup>>((ref) {
  final service = ref.watch(supabaseGroupServiceProvider);
  return service.getAllGroupsStream();
});

// Provider for user's groups
final userGroupsProvider = FutureProvider<List<CapoeiraGroup>>((ref) async {
  final service = ref.watch(supabaseGroupServiceProvider);
  // Get current user ID from Firebase Auth
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return [];
  
  return service.getUserGroups(currentUser.id);
});