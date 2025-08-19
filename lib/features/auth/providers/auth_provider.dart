import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/application/auth_controller.dart';
import 'package:roda/core/models/user_model.dart';

// Re-export providers from auth_controller for backward compatibility
export 'package:roda/application/auth_controller.dart' show authStateProvider, currentUserProvider;

// Legacy provider - use authControllerProvider instead

// Legacy provider - redirect to new auth controller
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref);
});

// Legacy AuthService - wraps new AuthController for backward compatibility
class AuthService {
  final Ref _ref;
  
  AuthService(this._ref);
  
  AuthController get _authController => _ref.read(authControllerProvider);
  
  Future<UserModel?> signInWithGoogle() async {
    return _authController.signInWithGoogle();
  }
  
  Future<UserModel?> signInWithApple() async {
    return _authController.signInWithApple();
  }
  
  Future<UserModel?> signInWithEmailPassword(String email, String password) async {
    return _authController.signInWithEmailPassword(
      email: email,
      password: password,
    );
  }
  
  Future<UserModel> signUpWithEmailPassword({
    required String email,
    required String password,
    required String fullName,
    required String capoeiraName,
    required DateTime dateOfBirth,
    required UserRole role,
  }) async {
    return _authController.signUpWithEmailPassword(
      email: email,
      password: password,
      fullName: fullName,
      capoeiraName: capoeiraName,
      dateOfBirth: dateOfBirth,
      role: role,
    );
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
    return _authController.completeUserProfile(
      fullName: fullName,
      capoeiraName: capoeiraName,
      dateOfBirth: dateOfBirth,
      role: role,
      groupBranch: groupBranch,
    );
  }
  
  Future<void> signOut() async {
    return _authController.signOut();
  }
  
  Future<void> deleteAccount() async {
    return _authController.deleteAccount();
  }
}