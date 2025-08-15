import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/models/class_session_model.dart' hide EventType, RecurrenceType;
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/models/class_instance.dart' hide ClassStatus;
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/classes/providers/class_providers.dart';
import 'package:roda/features/teacher/presentation/pages/schedule_templates_page.dart';
import 'package:roda/features/teacher/presentation/pages/class_attendance_page.dart';
import 'package:roda/features/teacher/providers/schedule_providers.dart';
import 'package:intl/intl.dart';

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return SafeScaffold(
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final userId = ref.read(currentUserProvider).value?.id;
              if (userId != null) {
                ref.invalidate(teacherUpcomingFullClassesProvider(userId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Refreshing...'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to teacher settings
            },
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data'));
          }
          
          final upcomingClasses = ref.watch(
            teacherUpcomingFullClassesProvider(user.id),
          );
          
          return upcomingClasses.when(
            data: (classes) => _buildDashboardContent(context, ref, classes),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScheduleSetupDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Schedule Class'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    List<FullClassData> classes,
  ) {
    if (classes.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No upcoming classes',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final userId = ref.read(currentUserProvider).value?.id;
        if (userId != null) {
          ref.invalidate(teacherUpcomingFullClassesProvider(userId));
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSummaryCard(classes),
          const SizedBox(height: 16),
          // Quick Actions
          _buildQuickActions(context, ref),
          const SizedBox(height: 24),
          const Text(
            'Upcoming Classes',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...classes.map((classSession) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildClassCard(context, classSession),
          )),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(List<FullClassData> classes) {
    final totalAttending = classes.fold<int>(
      0,
      (sum, c) => sum + c.attendingStudentIds.length,
    );
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Upcoming Classes',
                  classes.length.toString(),
                  Icons.calendar_today,
                ),
                _buildSummaryItem(
                  'Students Attending',
                  totalAttending.toString(),
                  Icons.people,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildClassCard(BuildContext context, FullClassData classSession) {
    final dateFormat = DateFormat('EEEE, MMM dd');
    final timeRange = '${classSession.startTime} - ${classSession.endTime}';
    final attendingCount = classSession.attendingStudentIds.length;
    final presentCount = classSession.presentStudentIds.length;
    final paidCount = classSession.instance.paymentConfirmations.values
        .where((p) => p.status == PaymentStatus.confirmed || p.status == PaymentStatus.verified)
        .length;
    
    // Determine if this is a roda or class
    final isRoda = classSession.eventType == EventType.roda;
    final eventTypeLabel = isRoda ? 'RODA' : 'CLASS';
    final tagColor = isRoda ? Colors.orange : Colors.blue;
    
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ClassAttendancePage(classData: classSession),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
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
                          dateFormat.format(classSession.scheduledDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeRange,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 16,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$attendingCount attending',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                        if (presentCount > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.green[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$presentCount present',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                        if (classSession.price != null && classSession.price! > 0) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.attach_money,
                            size: 16,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$paidCount/$attendingCount paid',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClassDetails(BuildContext context, FullClassData classSession) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
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
                    DateFormat('EEEE, MMM dd, yyyy')
                        .format(classSession.scheduledDate),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${classSession.startTime} - ${classSession.endTime}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildAttendanceSection(
                    'Students Attending',
                    classSession.attendingStudentIds.length,
                    Icons.people_outline,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildAttendanceSection(
                    'Students Present',
                    classSession.presentStudentIds.length,
                    Icons.check_circle_outline,
                    Colors.green,
                  ),
                  const SizedBox(height: 32),
                  if (classSession.status == ClassStatus.scheduled)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // TODO: Implement class cancellation
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel Class'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceSection(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16),
        ),
        const Spacer(),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildActionCard(
            context,
            'Take Attendance',
            Icons.check_circle_outline,
            Colors.green,
            () {
              // TODO: Navigate to attendance
            },
          ),
          const SizedBox(width: 12),
          _buildActionCard(
            context,
            'View Students',
            Icons.people,
            Colors.orange,
            () {
              // TODO: Navigate to students list
            },
          ),
          const SizedBox(width: 12),
          _buildActionCard(
            context,
            'Send Message',
            Icons.message,
            Colors.purple,
            () {
              // TODO: Navigate to messaging
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleSetupDialog(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ScheduleTemplatesPage(),
      ),
    );
    
    // Refresh the dashboard when returning from schedule page
    final currentUser = ref.read(currentUserProvider).value;
    if (currentUser != null) {
      ref.invalidate(teacherUpcomingFullClassesProvider(currentUser.id));
    }
  }
}