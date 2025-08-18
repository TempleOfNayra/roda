import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class IdConverter {
  static const _uuid = Uuid();
  
  // Convert Firebase UID to a deterministic UUID
  static String firebaseToUuid(String firebaseUid) {
    // Create a deterministic UUID from Firebase UID using UUID v5 (SHA-1 based)
    // Using a namespace UUID for "firebase-auth"
    const namespace = '6ba7b810-9dad-11d1-80b4-00c04fd430c8';
    return _uuid.v5(namespace, firebaseUid);
  }
  
  // Store mapping if needed for reverse lookup
  static final Map<String, String> _firebaseToUuidCache = {};
  static final Map<String, String> _uuidToFirebaseCache = {};
  
  static String getUuid(String firebaseUid) {
    if (!_firebaseToUuidCache.containsKey(firebaseUid)) {
      final uuid = firebaseToUuid(firebaseUid);
      _firebaseToUuidCache[firebaseUid] = uuid;
      _uuidToFirebaseCache[uuid] = firebaseUid;
    }
    return _firebaseToUuidCache[firebaseUid]!;
  }
  
  static String? getFirebaseUid(String uuid) {
    return _uuidToFirebaseCache[uuid];
  }
}