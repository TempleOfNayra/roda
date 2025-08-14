import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/group_model.dart';

class GroupRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  CollectionReference<Map<String, dynamic>> get _groupsCollection =>
      _firestore.collection('groups');
  
  Stream<List<GroupModel>> getAllGroups() {
    return _groupsCollection
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  Stream<List<GroupModel>> getNearbyGroups({
    required double latitude,
    required double longitude,
    required double radiusInKm,
  }) {
    // Firestore doesn't support native geospatial queries
    // For a production app, you would use GeoFirestore or similar
    // For now, we'll fetch all groups and filter client-side
    
    return _groupsCollection
        .snapshots()
        .map((snapshot) {
          final allGroups = snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
              .toList();
          
          // Filter groups within radius
          return allGroups.where((group) {
            final distance = _calculateDistance(
              latitude,
              longitude,
              group.location.latitude,
              group.location.longitude,
            );
            return distance <= radiusInKm;
          }).toList();
        });
  }
  
  Future<void> createGroup(GroupModel group) async {
    try {
      await _groupsCollection.add(group.toMap());
    } catch (e) {
      throw Exception('Failed to create group: $e');
    }
  }
  
  Future<void> updateGroup(GroupModel group) async {
    try {
      await _groupsCollection.doc(group.id).update(group.toMap());
    } catch (e) {
      throw Exception('Failed to update group: $e');
    }
  }
  
  Future<GroupModel?> getGroup(String groupId) async {
    try {
      final doc = await _groupsCollection.doc(groupId).get();
      
      if (!doc.exists) return null;
      
      return GroupModel.fromMap(doc.data()!, doc.id);
    } catch (e) {
      throw Exception('Failed to get group: $e');
    }
  }
  
  Stream<GroupModel?> getGroupStream(String groupId) {
    return _groupsCollection.doc(groupId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return GroupModel.fromMap(snapshot.data()!, snapshot.id);
    });
  }
  
  // Helper method to calculate distance between two points
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // km
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }
  
  double _toRadians(double degree) {
    return degree * (pi / 180);
  }
  
  static const double pi = 3.14159265359;
  
  double sin(double x) => _sin(x);
  double cos(double x) => _cos(x);
  double sqrt(double x) => _sqrt(x);
  double atan2(double y, double x) => _atan2(y, x);
  
  // Basic math function implementations
  double _sin(double x) {
    // Simple Taylor series approximation
    double term = x;
    double sum = x;
    
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      sum += term;
    }
    
    return sum;
  }
  
  double _cos(double x) {
    return _sin(x + pi / 2);
  }
  
  double _sqrt(double x) {
    if (x < 0) return double.nan;
    if (x == 0) return 0;
    
    double guess = x / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + x / guess) / 2;
    }
    
    return guess;
  }
  
  double _atan2(double y, double x) {
    // Simplified atan2 implementation
    if (x > 0) {
      return _atan(y / x);
    } else if (x < 0 && y >= 0) {
      return _atan(y / x) + pi;
    } else if (x < 0 && y < 0) {
      return _atan(y / x) - pi;
    } else if (x == 0 && y > 0) {
      return pi / 2;
    } else if (x == 0 && y < 0) {
      return -pi / 2;
    }
    return 0;
  }
  
  double _atan(double x) {
    // Simple Taylor series approximation
    double sum = 0;
    double term = x;
    
    for (int i = 0; i < 10; i++) {
      sum += term / (2 * i + 1);
      term *= -x * x;
    }
    
    return sum;
  }
}