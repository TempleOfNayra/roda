// Mock authentication provider for local development
// This bypasses Firebase authentication

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roda/core/models/user_model.dart';

// Override the auth state provider to return null (not signed in)
final mockAuthStateProvider = StreamProvider<User?>((ref) {
  // Return a stream that emits null, simulating no user signed in
  return Stream.value(null);
});

// Override the current user provider to return null
final mockCurrentUserProvider = StreamProvider<UserModel?>((ref) {
  return Stream.value(null);
});

// Mock auth service that does nothing but allows the app to run
class MockAuthService {
  Future<UserModel?> signInWithGoogle() async {
    // Return null to simulate no sign in
    return null;
  }
  
  Future<UserModel?> signInWithApple() async {
    // Return null to simulate no sign in
    return null;
  }
  
  Future<UserModel> createUser({
    required String fullName,
    required String capoeiraName,
    required DateTime dateOfBirth,
    required UserRole role,
    String? groupName,
    String? teacherName,
  }) async {
    // Return a mock user
    return UserModel(
      id: 'mock-user-id',
      email: 'mock@example.com',
      fullName: fullName,
      capoeiraName: capoeiraName,
      dateOfBirth: dateOfBirth,
      role: role,
      groupName: groupName,
      teacherName: teacherName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
  
  Future<void> updateUser(UserModel user) async {
    // Do nothing in mock
  }
  
  Future<void> signOut() async {
    // Do nothing in mock
  }
}

final mockAuthServiceProvider = Provider<MockAuthService>((ref) {
  return MockAuthService();
});