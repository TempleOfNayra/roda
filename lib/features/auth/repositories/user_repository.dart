import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/main.dart'; // For useMockMode flag

final userRepositoryProvider = Provider<UserRepository>((ref) {
  if (useMockMode) {
    return MockUserRepository();
  }
  return UserRepository(FirebaseFirestore.instance);
});

class UserRepository {
  final FirebaseFirestore _firestore;
  
  UserRepository(this._firestore);
  
  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');
  
  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _usersCollection.doc(userId).get();
      
      if (!doc.exists) return null;
      
      return UserModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }
  
  Stream<UserModel?> getUserStream(String userId) {
    return _usersCollection.doc(userId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return UserModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }
  
  Future<void> createUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.id).set(user.toMap());
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }
  
  Future<void> updateUser(UserModel user) async {
    try {
      await _usersCollection.doc(user.id).update({
        ...user.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }
  
  Future<List<UserModel>> getUsersByGroup(String groupId) async {
    try {
      final querySnapshot = await _usersCollection
          .where('groupId', isEqualTo: groupId)
          .get();
      
      return querySnapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users by group: $e');
    }
  }
  
  Stream<List<UserModel>> getUsersByGroupStream(String groupId) {
    return _usersCollection
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .toList());
  }
}

// Mock repository for development without Firebase
class MockUserRepository extends UserRepository {
  MockUserRepository() : super(FirebaseFirestore.instance);
  
  @override
  Future<UserModel?> getUser(String userId) async {
    // Return null to simulate no user found
    return null;
  }
  
  @override
  Stream<UserModel?> getUserStream(String userId) {
    // Return empty stream
    return Stream.value(null);
  }
  
  @override
  Future<void> createUser(UserModel user) async {
    // Do nothing in mock mode
    print('Mock: Would create user ${user.capoeiraName}');
  }
  
  @override
  Future<void> updateUser(UserModel user) async {
    // Do nothing in mock mode
    print('Mock: Would update user ${user.capoeiraName}');
  }
  
  @override
  Future<List<UserModel>> getUsersByGroup(String groupId) async {
    // Return empty list
    return [];
  }
  
  @override
  Stream<List<UserModel>> getUsersByGroupStream(String groupId) {
    // Return empty stream
    return Stream.value([]);
  }
}