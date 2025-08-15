import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/class_instance.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/features/teacher/providers/schedule_providers.dart';
import 'package:intl/intl.dart';

class ClassAttendancePage extends ConsumerWidget {
  final FullClassData classData;
  
  const ClassAttendancePage({
    super.key,
    required this.classData,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    final timeRange = '${classData.startTime} - ${classData.endTime}';
    
    return SafeScaffold(
      appBar: AppBar(
        title: const Text('Class Details'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh the class data
              ref.invalidate(classInstanceStreamProvider(classData.instance.id));
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('class_instances')
            .doc(classData.instance.id)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final updatedInstance = ClassInstance.fromFirestore(snapshot.data!);
          
          return Column(
            children: [
              // Class info header
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateFormat.format(classData.scheduledDate),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeRange,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            classData.location,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (classData.price != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Price: \$${classData.price!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Summary stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Registered',
                          updatedInstance.attendingStudentIds.length.toString(),
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Present',
                          updatedInstance.presentStudentIds.length.toString(),
                          Colors.green,
                        ),
                        _buildStatCard(
                          'Paid',
                          updatedInstance.paymentConfirmations.values
                              .where((p) => p.status == PaymentStatus.confirmed)
                              .length
                              .toString(),
                          Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Student list header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: const Row(
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Registered Students',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Student list
              Expanded(
                child: updatedInstance.attendingStudentIds.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'No registered students yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: updatedInstance.attendingStudentIds.length,
                        itemBuilder: (context, index) {
                          final studentId = updatedInstance.attendingStudentIds[index];
                          return _StudentListItem(
                            studentId: studentId,
                            classInstance: updatedInstance,
                            classData: classData,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentListItem extends ConsumerWidget {
  final String studentId;
  final ClassInstance classInstance;
  final FullClassData classData;
  
  const _StudentListItem({
    required this.studentId,
    required this.classInstance,
    required this.classData,
  });
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(Icons.person)),
              title: Text('Loading...'),
            ),
          );
        }
        
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final userName = userData['capoeiraName'] ?? userData['fullName'] ?? 'Unknown';
        final isPresent = classInstance.presentStudentIds.contains(studentId);
        final paymentInfo = classInstance.paymentConfirmations[studentId];
        final paymentStatus = paymentInfo?.status ?? PaymentStatus.unpaid;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isPresent ? Colors.green : Colors.grey[300],
              child: Text(
                userName[0].toUpperCase(),
                style: TextStyle(
                  color: isPresent ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
            title: Text(userName),
            subtitle: Row(
              children: [
                // Attendance status
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPresent 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPresent ? 'Present' : 'Registered',
                    style: TextStyle(
                      fontSize: 11,
                      color: isPresent ? Colors.green[700] : Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Payment status
                if (classData.price != null && classData.price! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getPaymentStatusColor(paymentStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getPaymentStatusIcon(paymentStatus),
                          size: 12,
                          color: _getPaymentStatusColor(paymentStatus),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _getPaymentStatusText(paymentStatus),
                          style: TextStyle(
                            fontSize: 11,
                            color: _getPaymentStatusColor(paymentStatus),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'toggle_attendance':
                    await _toggleAttendance(context, ref);
                    break;
                  case 'verify_payment':
                    await _verifyPayment(context, ref);
                    break;
                  case 'unconfirm_payment':
                    await _unconfirmPayment(context, ref);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_attendance',
                  child: Text(isPresent ? 'Mark as Absent' : 'Mark as Present'),
                ),
                if (classData.price != null && classData.price! > 0) ...[
                  if (paymentStatus != PaymentStatus.verified)
                    const PopupMenuItem(
                      value: 'verify_payment',
                      child: Text('Verify Payment'),
                    ),
                  if (paymentStatus != PaymentStatus.unpaid)
                    const PopupMenuItem(
                      value: 'unconfirm_payment',
                      child: Text('Mark as Unpaid'),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
  
  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid:
        return Colors.red;
      case PaymentStatus.confirmed:
        return Colors.orange;
      case PaymentStatus.verified:
        return Colors.green;
    }
  }
  
  IconData _getPaymentStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid:
        return Icons.money_off;
      case PaymentStatus.confirmed:
        return Icons.hourglass_empty;
      case PaymentStatus.verified:
        return Icons.check_circle;
    }
  }
  
  String _getPaymentStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.unpaid:
        return 'Unpaid';
      case PaymentStatus.confirmed:
        return 'Confirmed';
      case PaymentStatus.verified:
        return 'Verified';
    }
  }
  
  Future<void> _toggleAttendance(BuildContext context, WidgetRef ref) async {
    final isPresent = classInstance.presentStudentIds.contains(studentId);
    
    try {
      await FirebaseFirestore.instance
          .collection('class_instances')
          .doc(classInstance.id)
          .update({
        'presentStudentIds': isPresent
            ? FieldValue.arrayRemove([studentId])
            : FieldValue.arrayUnion([studentId]),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPresent ? 'Marked as absent' : 'Marked as present'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _verifyPayment(BuildContext context, WidgetRef ref) async {
    try {
      await FirebaseFirestore.instance
          .collection('class_instances')
          .doc(classInstance.id)
          .update({
        'paymentConfirmations.$studentId': {
          'status': PaymentStatus.verified.name,
          'confirmedAt': FieldValue.serverTimestamp(),
          'paymentMethod': 'venmo',
        }
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verified'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _unconfirmPayment(BuildContext context, WidgetRef ref) async {
    try {
      await FirebaseFirestore.instance
          .collection('class_instances')
          .doc(classInstance.id)
          .update({
        'paymentConfirmations.$studentId': FieldValue.delete(),
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Marked as unpaid'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Provider for streaming class instance updates
final classInstanceStreamProvider = StreamProvider.family<ClassInstance, String>((ref, instanceId) {
  return FirebaseFirestore.instance
      .collection('class_instances')
      .doc(instanceId)
      .snapshots()
      .map((doc) => ClassInstance.fromFirestore(doc));
});