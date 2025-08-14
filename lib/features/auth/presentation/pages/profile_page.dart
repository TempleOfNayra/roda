import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/models/class_instance.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/core/utils/venmo_helper.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/teacher/providers/schedule_providers.dart';
import 'package:roda/features/groups/providers/group_providers.dart';
import 'package:intl/intl.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.main),
        ),
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          // Show teacher dashboard button if user is a teacher or has teaching groups
          Consumer(
            builder: (context, ref, child) {
              final user = ref.watch(currentUserProvider).value;
              final isTeacher = user?.role == UserRole.teacher || 
                               (user?.teachingGroupIds.isNotEmpty ?? false);
              
              if (isTeacher) {
                return IconButton(
                  icon: const Icon(Icons.dashboard),
                  tooltip: 'Teacher Dashboard',
                  onPressed: () => context.push(Routes.teacherDashboard),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(Routes.editProfile),
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data'));
          }
          
          final registeredClasses = ref.watch(userRegisteredClassesProvider(user.id));
          
          return Column(
            children: [
              // Condensed profile info at top
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                      child: Text(
                        user.capoeiraName.isNotEmpty 
                            ? user.capoeiraName[0].toUpperCase() 
                            : 'U',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.capoeiraName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (user.groupName != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.group, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  user.groupName!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Section header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'My Upcoming Classes & Rodas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              // List of registered classes
              Expanded(
                child: registeredClasses.when(
                  data: (classes) {
                    if (classes.isEmpty) {
                      return Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No registered classes',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Visit the map to find and register for classes',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => context.push(Routes.map),
                                icon: const Icon(Icons.map),
                                label: const Text('Go to Map'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: classes.length,
                      itemBuilder: (context, index) {
                        final classData = classes[index];
                        return _buildClassCard(context, ref, classData, user.id);
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text('Error loading classes: $error'),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
  
  Widget _buildClassCard(
    BuildContext context,
    WidgetRef ref,
    FullClassData classData,
    String userId,
  ) {
    final dateFormat = DateFormat('EEEE, MMM dd');
    final timeRange = '${classData.startTime} - ${classData.endTime}';
    final isRoda = classData.eventType == EventType.roda;
    final eventTypeLabel = isRoda ? 'RODA' : 'CLASS';
    final tagColor = isRoda ? Colors.orange : Colors.blue;
    final isPresent = classData.presentStudentIds.contains(userId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          _showClassDetails(context, ref, classData, userId);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: tagColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      eventTypeLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(classData.scheduledDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (isPresent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Attended',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
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
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    classData.groupName,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.people_outline, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${classData.attendingStudentIds.length} attending',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (classData.price != null) ...[
                    const Spacer(),
                    Text(
                      '\$${classData.price!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Pay and Cancel Registration buttons
              if (!isPresent)
                Row(
                  children: [
                    // Pay button
                    if (classData.price != null && classData.price! > 0)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              // Get the group's Venmo handle
                              final groupAsync = await ref.read(groupByIdProvider(classData.template.groupId).future);
                              
                              if (groupAsync == null || groupAsync.venmoHandle == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Payment information not available'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              
                              final eventType = classData.eventType == EventType.roda ? 'Roda' : 'Class';
                              final dateStr = DateFormat('MMM d').format(classData.scheduledDate);
                              final note = '$eventType - $dateStr - ${classData.groupName}';
                              
                              final success = await VenmoHelper.launchVenmoPayment(
                                venmoHandle: groupAsync.venmoHandle!,
                                amount: classData.price,
                                note: note,
                              );
                              
                              if (!success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open Venmo'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.attach_money, size: 18),
                            label: const Text('Pay with Venmo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green[700],
                              side: BorderSide(color: Colors.green.shade400),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                    // Cancel Registration button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          // Show confirmation dialog
                          final shouldCancel = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Cancel Registration?'),
                              content: Text(
                                'Are you sure you want to cancel your registration for this ${isRoda ? "roda" : "class"}?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Keep Registration'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Cancel Registration'),
                                ),
                              ],
                            ),
                          );
                          
                          if (shouldCancel == true) {
                            try {
                              // Remove from attending list
                              await FirebaseFirestore.instance
                                  .collection('class_instances')
                                  .doc(classData.instance.id)
                                  .update({
                                'attendingStudentIds': FieldValue.arrayRemove([userId]),
                              });
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Registration cancelled'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              
                              // Refresh the list
                              ref.invalidate(userRegisteredClassesProvider(userId));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to cancel registration: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel Registration'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showClassDetails(
    BuildContext context,
    WidgetRef ref,
    FullClassData classData,
    String userId,
  ) {
    final isPresent = classData.presentStudentIds.contains(userId);
    final dateFormat = DateFormat('EEEE, MMMM dd, yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                classData.eventType == EventType.roda ? 'Roda Details' : 'Class Details',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                dateFormat.format(classData.scheduledDate),
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                '${classData.startTime} - ${classData.endTime}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Text(
                      'Price: \$${classData.price!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              if (!isPresent) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // Remove from attending list
                      await FirebaseFirestore.instance
                          .collection('class_instances')
                          .doc(classData.instance.id)
                          .update({
                        'attendingStudentIds': FieldValue.arrayRemove([userId]),
                      });
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Registration cancelled'),
                          ),
                        );
                        // Refresh the list
                        ref.invalidate(userRegisteredClassesProvider(userId));
                      }
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel Registration'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Text(
                        'You attended this ${classData.eventType == EventType.roda ? 'roda' : 'class'}',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}