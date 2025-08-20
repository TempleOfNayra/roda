import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:roda/core/models/user_model.dart';
import 'package:roda/data/repositories/auth_repository.dart';
import 'package:roda/data/repositories/user_repository.dart';
import 'package:roda/data/repositories/group_repository.dart';
import 'package:roda/data/core/db_exceptions.dart' as app_exceptions;
import 'package:roda/core/utils/logger.dart';
import 'package:roda/main.dart'; // For useMockMode flag

final authStateProvider = StreamProvider<User?>((ref) {
  if (useMockMode) {
    return Stream.value(null);
  }
  
  try {
    final authRepository = ref.watch(authRepositoryProvider);
    return authRepository.authStateChanges.handleError((error, stack) {
      Logger.debug('Auth stream error: $error');
      Logger.debug('Stack trace: $stack');
      // Don't throw error, continue with current state
    });
  } catch (e) {
    Logger.debug('Failed to setup auth stream: $e');
    return Stream.value(null);
  }
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      try {
        return userRepository.getUserStream(user.id).handleError((error, stack) {
          Logger.debug('User stream error: $error');
          Logger.debug('Stack trace: $stack');
          // Don't throw error, continue with current state
        });
      } catch (e) {
        Logger.debug('Failed to get user stream: $e');
        return Stream.value(null);
      }
    },
    loading: () => Stream.value(null),
    error: (error, stack) {
      Logger.debug('Auth state error: $error');
      return Stream.value(null);
    },
  );
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});

class AuthController {
  final Ref _ref;
  
  AuthController(this._ref);
  
  AuthRepository get _authRepository => _ref.read(authRepositoryProvider);
  UserRepository get _userRepository => _ref.read(userRepositoryProvider);
  GroupRepository get _groupRepository => _ref.read(groupRepositoryProvider);
  
  Future<UserModel?> signInWithGoogle() async {
    try {
      Logger.debug('Starting Google Sign In...');
      
      final authResponse = await _authRepository.signInWithGoogle();
      
      if (authResponse.user == null) {
        Logger.debug('No user returned from Google sign in');
        return null;
      }
      
      final existingUser = await _userRepository.getUser(authResponse.user!.id);
      
      if (existingUser != null) {
        Logger.debug('Existing user found');
        return existingUser;
      }
      
      Logger.debug('New user - needs to complete profile');
      return null;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Google Sign In Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<UserModel?> signInWithApple() async {
    try {
      Logger.debug('Starting Apple Sign In...');
      
      final authResponse = await _authRepository.signInWithApple();
      
      if (authResponse.user == null) {
        Logger.debug('No user returned from Apple sign in');
        return null;
      }
      
      final existingUser = await _userRepository.getUser(authResponse.user!.id);
      
      if (existingUser != null) {
        Logger.debug('Existing user found');
        return existingUser;
      }
      
      Logger.debug('New user - needs to complete profile');
      return null;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Apple Sign In Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<UserModel?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      Logger.debug('Starting email/password sign in...');
      
      final authResponse = await _authRepository.signInWithEmailPassword(
        email: email,
        password: password,
      );
      
      if (authResponse.user == null) {
        throw app_exceptions.AuthException('Sign in failed - no user returned');
      }
      
      return await _userRepository.getUser(authResponse.user!.id);
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Email/Password Sign In Error: ${appException.message}');
      throw appException;
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
      Logger.debug('Starting email/password sign up...');
      
      final authResponse = await _authRepository.signUpWithEmailPassword(
        email: email,
        password: password,
      );
      
      if (authResponse.user == null) {
        throw app_exceptions.AuthException('Sign up failed - no user returned');
      }
      
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
      
      return await _userRepository.createUser(userModel);
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Email/Password Sign Up Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<UserModel> completeUserProfile({
    required String fullName,
    required String capoeiraName,
    required DateTime dateOfBirth,
    required UserRole role,
    String? groupBranch,
  }) async {
    try {
      Logger.debug('Completing user profile...');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      final userModel = UserModel(
        id: currentUser.id,
        email: currentUser.email ?? '',
        fullName: fullName,
        capoeiraName: capoeiraName,
        dateOfBirth: dateOfBirth,
        role: role,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      final createdUser = await _userRepository.createUser(userModel);
      
      if (groupBranch != null && groupBranch.isNotEmpty && role == UserRole.student) {
        try {
          final existingGroup = await _groupRepository.getGroupByDisplayName(groupBranch);
          
          if (existingGroup != null) {
            await _groupRepository.addMemberToGroup(existingGroup.id, currentUser.id);
            Logger.debug('User joined existing group: ${existingGroup.displayName}');
          }
        } catch (e) {
          Logger.debug('Error joining group: $e');
        }
      }
      
      return createdUser;
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Complete Profile Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> signOut() async {
    try {
      Logger.debug('Signing out user...');
      await _authRepository.signOut();
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Sign Out Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> deleteAccount() async {
    try {
      Logger.debug('Deleting user account...');
      
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw app_exceptions.AuthException('No authenticated user');
      }
      
      await _userRepository.deleteUser(currentUser.id);
      await _authRepository.signOut();
      
      Logger.debug('Account deleted successfully');
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Delete Account Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> resetPassword(String email) async {
    try {
      Logger.debug('Sending password reset email...');
      await _authRepository.resetPassword(email);
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Reset Password Error: ${appException.message}');
      throw appException;
    }
  }
  
  Future<void> updatePassword(String newPassword) async {
    try {
      Logger.debug('Updating password...');
      await _authRepository.updatePassword(newPassword);
    } catch (e) {
      final appException = e is app_exceptions.AppException ? e : app_exceptions.ExceptionMapper.mapSupabaseError(e);
      Logger.debug('Update Password Error: ${appException.message}');
      throw appException;
    }
  }
}