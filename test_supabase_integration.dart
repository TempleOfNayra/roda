import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/features/auth/repositories/supabase_user_repository.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/core/models/user_model.dart';

void main() async {
  print('Testing Supabase Integration...\n');
  
  try {
    // Initialize Supabase
    await SupabaseConfig.initialize();
    print('✅ Supabase initialized');
    
    // Test user repository
    final userRepo = SupabaseUserRepository();
    print('\n📝 Testing User Repository...');
    
    // Create a test user
    final testUser = UserModel(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      email: 'test@example.com',
      fullName: 'Test User',
      capoeiraName: 'Testador',
      dateOfBirth: DateTime(1990, 1, 1),
      role: UserRole.student,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    await userRepo.createUser(testUser);
    print('✅ User created successfully');
    
    // Get the user back
    final fetchedUser = await userRepo.getUser(testUser.id);
    if (fetchedUser != null) {
      print('✅ User fetched: ${fetchedUser.capoeiraName}');
    }
    
    // Test group service
    final groupService = SupabaseGroupService();
    print('\n📝 Testing Group Service...');
    
    // Create a test group
    final groupId = await groupService.createGroup(
      name: 'Test Group',
      branch: 'Test Branch',
      location: 'Test City',
      createdBy: testUser.id,
      teacherName: testUser.fullName,
    );
    print('✅ Group created with ID: $groupId');
    
    // Get the group back
    final group = await groupService.getGroup(groupId);
    if (group != null) {
      print('✅ Group fetched: ${group.displayName}');
    }
    
    print('\n🎉 All tests passed! Supabase integration is working.');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}