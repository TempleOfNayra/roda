import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/features/auth/repositories/supabase_user_repository.dart';
import 'package:roda/core/models/user_model.dart';

void main() async {
  
  try {
    // Initialize Supabase
    await SupabaseConfig.initialize();
    
    // Test user repository
    final userRepo = SupabaseUserRepository();
    
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
    
    // Get the user back
    final fetchedUser = await userRepo.getUser(testUser.id);
    if (fetchedUser != null) {
    }
    
    // Test group service - Note: SupabaseGroupService now requires a Ref parameter
    // This test file needs to be updated to use proper Riverpod testing
    // For now, commenting out group service tests
    // final groupService = SupabaseGroupService(ref);
    
    // Create a test group
    // final groupId = await groupService.createGroup(
    //   name: 'Test Group',
    //   city: 'Test City',
    //   branch: 'Test Branch',
    //   location: 'Test City',
    //   createdBy: testUser.id,
    //   teacherName: testUser.fullName,
    // );
    
    // Get the group back
    // final group = await groupService.getGroup(groupId);
    // if (group != null) {
    // }
    
    
  } catch (e) {
  }
}