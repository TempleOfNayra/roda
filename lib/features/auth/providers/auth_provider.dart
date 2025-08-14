import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/features/auth/repositories/user_repository.dart';
import 'package:roda/features/groups/providers/group_providers.dart';
import 'package:roda/main.dart'; // For useMockMode flag

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<User?>((ref) {
  if (useMockMode) {
    // In mock mode, always return null (not signed in)
    return Stream.value(null);
  }
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  final userRepository = ref.watch(userRepositoryProvider);
  
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value(null);
      }
      return userRepository.getUserStream(user.uid);
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
  
  FirebaseAuth get _auth => _ref.read(firebaseAuthProvider);
  UserRepository get _userRepository => _ref.read(userRepositoryProvider);
  
  Future<UserModel?> signInWithGoogle() async {
    try {
      print('Starting Google Sign In...');
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        print('Google Sign In cancelled by user');
        return null;
      }
      
      print('Google user: ${googleUser.email}');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      print('Signing in with Firebase...');
      final userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        print('Firebase sign in failed - no user');
        return null;
      }
      
      print('Firebase user: ${userCredential.user!.uid}');
      // Check if user exists in Firestore
      final existingUser = await _userRepository.getUser(userCredential.user!.uid);
      
      if (existingUser != null) {
        print('Existing user found in Firestore');
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
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );
      
      final userCredential = await _auth.signInWithCredential(oauthCredential);
      
      if (userCredential.user == null) return null;
      
      // Check if user exists in Firestore
      final existingUser = await _userRepository.getUser(userCredential.user!.uid);
      
      if (existingUser != null) {
        return existingUser;
      }
      
      // Return null to redirect to sign-up flow
      return null;
    } catch (e) {
      throw Exception('Failed to sign in with Apple: $e');
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
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('No authenticated user');
      
      String? groupId;
      
      // If this is a teacher and they provided a group name, create the group
      if (role == UserRole.teacher && groupName != null && groupName.isNotEmpty) {
        // Use the GroupService to create the group properly
        final groupService = _ref.read(groupServiceProvider);
        
        // Create location string from city and country
        final location = groupCity != null && groupCountry != null 
            ? '$groupCity, $groupCountry'
            : groupCity ?? '';
        
        groupId = await groupService.createGroup(
          name: groupName,
          branch: groupAffiliation,
          description: null,
          location: location,
          venmoHandle: groupVenmo,
          createdBy: user.uid,
        );
      }
      
      final newUser = UserModel(
        id: user.uid,
        email: user.email ?? '',
        fullName: fullName,
        capoeiraName: capoeiraName,
        dateOfBirth: dateOfBirth,
        role: role,
        teachingGroupIds: groupId != null ? [groupId] : [],
        groupId: groupId,
        groupName: groupName,
        teacherName: teacherName,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await _userRepository.createUser(newUser);
      
      return newUser;
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }
  
  Future<void> updateUser(UserModel user) async {
    try {
      await _userRepository.updateUser(user);
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }
  
  Future<void> signOut() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      throw Exception('Failed to sign out: $e');
    }
  }
}