import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  
  // Your teacher user ID from the logs
  const teacherId = 'J7XirbWjLRQqowRdDLIi5XQRrgj2';
  const groupName = 'felihos de dungha';
  const teacherName = 'Professor'; // Update this with the actual teacher name
  
  try {
    // Create a group for the teacher
    final groupDoc = await firestore.collection('groups').add({
      'name': groupName,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'location': {
        'latitude': 0.0,
        'longitude': 0.0,
      },
      'memberCount': 1,
      'schedule': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('Created group with ID: ${groupDoc.id}');
    
    // Update the teacher's user document with the group ID
    await firestore.collection('users').doc(teacherId).update({
      'groupId': groupDoc.id,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    print('Updated teacher with group ID: ${groupDoc.id}');
    print('Fix completed successfully!');
  } catch (e) {
    print('Error: $e');
  }
}