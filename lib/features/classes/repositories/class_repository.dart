import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/class_session_model.dart';

class ClassRepository {
  final FirebaseFirestore _firestore;
  
  ClassRepository(this._firestore);
  
  CollectionReference<Map<String, dynamic>> get _classesCollection =>
      _firestore.collection('classes');
  
  Future<void> createClass(ClassSessionModel classSession) async {
    try {
      await _classesCollection.add(classSession.toMap());
    } catch (e) {
      throw Exception('Failed to create class: $e');
    }
  }
  
  Stream<ClassSessionModel?> getNextClassForGroup(String groupId) {
    final now = DateTime.now();
    
    return _classesCollection
        .where('groupId', isEqualTo: groupId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('status', isEqualTo: ClassStatus.scheduled.name)
        .orderBy('scheduledDate')
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return ClassSessionModel.fromMap(doc.data(), doc.id);
        });
  }
  
  Stream<List<ClassSessionModel>> getUpcomingClassesForGroup(String groupId) {
    final now = DateTime.now();
    
    return _classesCollection
        .where('groupId', isEqualTo: groupId)
        .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('scheduledDate')
        .limit(10)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClassSessionModel.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  Stream<List<ClassSessionModel>> getUpcomingClassesForTeacher(String teacherId) {
    final now = DateTime.now();
    
    print('getUpcomingClassesForTeacher called for teacherId: $teacherId');
    
    // First get all groups for this teacher
    return _firestore
        .collection('groups')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .asyncMap((groupSnapshot) async {
          print('Found ${groupSnapshot.docs.length} groups for teacher $teacherId');
          if (groupSnapshot.docs.isEmpty) {
            print('No groups found, trying direct teacher query...');
            
            // Fallback: Try getting classes directly by teacherId
            final directClassesSnapshot = await _classesCollection
                .where('teacherId', isEqualTo: teacherId)
                .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
                .orderBy('scheduledDate')
                .limit(20)
                .get();
            
            print('Found ${directClassesSnapshot.docs.length} classes directly by teacherId');
            
            return directClassesSnapshot.docs
                .map((doc) => ClassSessionModel.fromMap(doc.data(), doc.id))
                .toList();
          }
          
          final groupIds = groupSnapshot.docs.map((doc) => doc.id).toList();
          print('Group IDs: $groupIds');
          
          // Then get all upcoming classes for those groups
          final classesSnapshot = await _classesCollection
              .where('groupId', whereIn: groupIds)
              .where('scheduledDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
              .orderBy('scheduledDate')
              .limit(20)
              .get();
          
          print('Found ${classesSnapshot.docs.length} classes for groups');
          
          return classesSnapshot.docs
              .map((doc) => ClassSessionModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }
  
  Future<void> addAttendingStudent(String classId, String userId) async {
    try {
      await _classesCollection.doc(classId).update({
        'attendingStudentIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to add attending student: $e');
    }
  }
  
  Future<void> removeAttendingStudent(String classId, String userId) async {
    try {
      await _classesCollection.doc(classId).update({
        'attendingStudentIds': FieldValue.arrayRemove([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to remove attending student: $e');
    }
  }
  
  Future<void> markStudentPresent(String classId, String userId) async {
    try {
      await _classesCollection.doc(classId).update({
        'presentStudentIds': FieldValue.arrayUnion([userId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to mark student present: $e');
    }
  }
  
  Future<void> updateClassStatus(String classId, ClassStatus status) async {
    try {
      await _classesCollection.doc(classId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to update class status: $e');
    }
  }
  
  Future<int> getCompletedClassCount(String groupId) async {
    try {
      final snapshot = await _classesCollection
          .where('groupId', isEqualTo: groupId)
          .where('status', isEqualTo: ClassStatus.completed.name)
          .count()
          .get();
      
      return snapshot.count ?? 0;
    } catch (e) {
      throw Exception('Failed to get completed class count: $e');
    }
  }
}