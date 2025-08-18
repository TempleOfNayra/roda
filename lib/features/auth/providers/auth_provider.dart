import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/features/auth/repositories/supabase_user_repository.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/main.dart'; // For useMockMode flag

final supabaseAuthProvider = Provider<GoTrueClient>((ref) {
  return SupabaseConfig.auth;
});

final authStateProvider = StreamProvider<User?>((ref) {
  if (useMockMode) {
    // In mock mode, always return null (not signed in)
    return Stream.value(null);
  }
  return ref.watch(supabaseAuthProvider).onAuthStateChange.map((event) => event.session?.user);
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final userRepository = ref.watch(supabaseUserRepositoryProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      // Use Supabase user ID
      return userRepository.getUserStream(user.id);
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

class AuthService {
  final Ref _ref;
  
  AuthService(this._ref);
  
  GoTrueClient get _auth => _ref.read(supabaseAuthProvider);
  SupabaseUserRepository get _userRepository => _ref.read(supabaseUserRepositoryProvider);
  
  Future<UserModel?> signInWithGoogle() async {
    try {
      print('Starting Google Sign In with Supabase...');
      final authResponse = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.nayra.roda://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      
      if (!authResponse) {
        print('Google Sign In cancelled or failed');
        return null;
      }
      
      final user = _auth.currentUser;
      if (user == null) {
        print('No user after Google sign in');
        return null;
      }
      
      print('Supabase user: ${user.id}');
      // Check if user profile exists
      final existingUser = await _userRepository.getUser(user.id);
      
      if (existingUser != null) {
        print('Existing user found');
        return existingUser;
      }
      
      print('New user - needs to complete profile');
      // Return null to redirect to sign-up flow
      return null;
    } catch (e, stack) {
      print('Google Sign In Error: $e');
      print('Stack trace: $stack');
      throw Exception('Failed to sign in with Google: $e');
    }
  }
  
  Future<UserModel?> signInWithApple() async {
    try {
      final authResponse = await _auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'io.nayra.roda://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      
      if (!authResponse) {
        return null;
      }
      
      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }
      
      // Check if user profile exists
      final existingUser = await _userRepository.getUser(user.id);
      
      if (existingUser != null) {
        return existingUser;
      }
      
      // Return null to redirect to sign-up flow
      return null;
    } catch (e) {
      throw Exception('Failed to sign in with Apple: $e');
    }
  }
  
  Future<UserModel?> signInWithEmailPassword(String email, String password) async {
    try {
      final authResponse = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (authResponse.user == null) {
        throw Exception('Sign in failed');
      }
      
      return await _userRepository.getUser(authResponse.user!.id);
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }
  
  Future<UserModel> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String capoeiraName,
    required DateTime dateOfBirth,
    required UserRole role,
  }) async {
    try {
      // Sign up with Supabase Auth
      final authResponse = await _auth.signUp(
        email: email,
        password: password,
      );
      
      if (authResponse.user == null) {
        throw Exception('Sign up failed');
      }
      
      // Create user profile in Supabase
      final userModel = UserModel(
        id: authResponse.user!.id,
        email: email,
        fullName: fullName,
        capoeiraName: capoeiraName,
        dateOfBirth: dateOfBirth,
        role: role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _userRepository.createUser(userModel);
      
      return userModel;
    } catch (e) {
      throw Exception('Failed to sign up: $e');
    }
  }
  
  Future<UserModel> createUser({
    required String fullName,
    required String capoeiraName,
    required DateTime dateOfBirth,
    required UserRole role,
    String? groupName,
    String? groupAffiliation,
    String? groupCity,
    String? groupCountry,
    String? groupVenmo,
    String? teacherName,
    bool joinExistingGroup = false,
  }) async {
    return completeUserProfile(
      fullName: fullName,
      capoeiraName: capoeiraName,
      dateOfBirth: dateOfBirth,
      role: role,
      groupBranch: groupName,
    );
  }

  Future<UserModel> completeUserProfile({
    required String fullName,
    required String capoeiraName,
    required DateTime dateOfBirth,
    required UserRole role,
    String? groupBranch,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }
      
      final userModel = UserModel(
        id: user.id,
        email: user.email ?? '',
        fullName: fullName,
        capoeiraName: capoeiraName,
        dateOfBirth: dateOfBirth,
        role: role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _userRepository.createUser(userModel);
      
      // Handle group association if provided
      if (groupBranch != null && groupBranch.isNotEmpty) {
        final groupService = _ref.read(supabaseGroupServiceProvider);
        try {
          final group = await groupService.getGroupByDisplayName(groupBranch);
          if (group != null) {
            if (role == UserRole.teacher) {
              await groupService.addTeacherToGroup(group.id, user.id);
            } else {
              await groupService.addMemberToGroup(group.id, user.id);
            }
          }
        } catch (e) {
          print('Error associating with group: $e');
        }
      }
      
      return userModel;
    } catch (e) {
      throw Exception('Failed to complete profile: $e');
    }
  }
  
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
  
  Future<void> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }
      
      // Delete user data from Supabase
      await _userRepository.deleteUser(user.id);
      
      // Delete from Supabase Auth
      // Note: This requires service role key on backend
      // For now, just sign out
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to delete account: $e');
    }
  }
}