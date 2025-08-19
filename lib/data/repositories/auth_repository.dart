import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;
import 'package:roda/data/core/base_repository.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/data/core/db_exceptions.dart' as app_exceptions;
import 'package:roda/core/utils/logger.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref);
});

class AuthRepository extends BaseRepository {
  AuthRepository(super.ref);
  
  GoTrueClient get _auth => ref.read(supabaseAuthClientProvider);
  
  User? get currentUser => _auth.currentUser;
  
  Stream<User?> get authStateChanges {
    return _auth.onAuthStateChange.map((event) => event.session?.user);
  }
  
  Future<AuthResponse> signInWithGoogle() async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Starting Google Sign In with Supabase...');
        
        final result = await _auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.nayra.roda://login-callback',
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        
        if (!result) {
          throw app_exceptions.AuthException('Google sign in was cancelled');
        }
        
        final session = _auth.currentSession;
        if (session == null) {
          throw app_exceptions.AuthException('Failed to establish session after Google sign in');
        }
        
        return AuthResponse(session: session, user: session.user);
      },
      operationName: 'Google Sign In',
    );
  }
  
  Future<AuthResponse> signInWithApple() async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Starting Apple Sign In with Supabase...');
        
        final result = await _auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: 'io.nayra.roda://login-callback',
          authScreenLaunchMode: LaunchMode.externalApplication,
        );
        
        if (!result) {
          throw app_exceptions.AuthException('Apple sign in was cancelled');
        }
        
        final session = _auth.currentSession;
        if (session == null) {
          throw app_exceptions.AuthException('Failed to establish session after Apple sign in');
        }
        
        return AuthResponse(session: session, user: session.user);
      },
      operationName: 'Apple Sign In',
    );
  }
  
  Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Signing in with email: $email');
        
        final response = await _auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (response.user == null) {
          throw app_exceptions.AuthException('Sign in failed - no user returned');
        }
        
        return response;
      },
      operationName: 'Email/Password Sign In',
    );
  }
  
  Future<AuthResponse> signUpWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Signing up with email: $email');
        
        final response = await _auth.signUp(
          email: email,
          password: password,
        );
        
        if (response.user == null) {
          throw app_exceptions.AuthException('Sign up failed - no user returned');
        }
        
        return response;
      },
      operationName: 'Email/Password Sign Up',
    );
  }
  
  Future<void> signOut() async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Signing out user');
        await _auth.signOut();
      },
      operationName: 'Sign Out',
    );
  }
  
  Future<void> resetPassword(String email) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Sending password reset email to: $email');
        await _auth.resetPasswordForEmail(email);
      },
      operationName: 'Password Reset',
    );
  }
  
  Future<void> updatePassword(String newPassword) async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Updating user password');
        await _auth.updateUser(UserAttributes(password: newPassword));
      },
      operationName: 'Update Password',
    );
  }
  
  Future<void> refreshSession() async {
    return executeWithErrorHandling(
      () async {
        Logger.debug('Refreshing auth session');
        await _auth.refreshSession();
      },
      operationName: 'Refresh Session',
    );
  }
}