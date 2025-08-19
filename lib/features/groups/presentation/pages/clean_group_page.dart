import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/teacher/providers/supabase_schedule_providers.dart';
import 'package:roda/application/group_controller.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:roda/features/teacher/presentation/widgets/styled_google_places_field.dart';
import 'package:roda/core/theme/form_theme.dart';

class CleanGroupPage extends ConsumerStatefulWidget {
  final String groupId;
  
  const CleanGroupPage({
    super.key,
    required this.groupId,
  });
  
  @override
  ConsumerState<CleanGroupPage> createState() => _CleanGroupPageState();
}

class _CleanGroupPageState extends ConsumerState<CleanGroupPage> {
  bool _isJoining = false;
  int _selectedTab = 0; // 0: Announcements, 1: Media
  
  Future<void> _joinGroup() async {
    setState(() => _isJoining = true);
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;
      
      final groupService = ref.read(supabaseGroupServiceProvider);
      await groupService.addMemberToGroup(widget.groupId, currentUser.id);
      ref.invalidate(groupByIdProvider(widget.groupId));
    } finally {
      setState(() => _isJoining = false);
    }
  }
  
  Future<void> _leaveGroup() async {
    setState(() => _isJoining = true);
    try {
      final currentUser = ref.read(currentUserProvider).value;
      if (currentUser == null) return;
      
      final groupService = ref.read(supabaseGroupServiceProvider);
      await groupService.removeMemberFromGroup(widget.groupId, currentUser.id);
      ref.invalidate(groupByIdProvider(widget.groupId));
    } finally {
      setState(() => _isJoining = false);
    }
  }
  
  Future<Map<String, dynamic>?> _getTeacherInfo(String teacherId) async {
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('capoeira_name, profile_picture')
          .eq('id', teacherId)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }
  
  Future<void> _deleteGroup(BuildContext context, CapoeiraGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Are you sure you want to delete ${group.displayName}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      try {
        final groupService = ref.read(supabaseGroupServiceProvider);
        // For now, just delete from groups table
        await SupabaseConfig.client
            .from('groups')
            .delete()
            .eq('id', widget.groupId);
        
        // Invalidate the user groups provider to refresh the list
        ref.invalidate(userGroupsProvider);
        
        if (context.mounted) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group deleted')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete group: $e')),
          );
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider).value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () {
              // Show options
            },
          ),
        ],
      ),
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }
          
          final isMember = group.memberIds.contains(currentUser?.id);
          final isTeacher = group.teacherIds.contains(currentUser?.id);
          final isAdmin = group.adminIds.contains(currentUser?.id);
          final primaryTeacherId = group.teacherIds.isNotEmpty ? group.teacherIds.first : null;
          
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean Header - Group info at top
                Container(
                  color: isDarkMode ? Colors.grey[900] : Colors.grey[100],
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Group Name
                      Text(
                        group.name.toUpperCase(),
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      // Affiliation
                      if (group.branch != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          group.branch!.toUpperCase(),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      
                      // City
                      if (group.city != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          group.city!.toUpperCase(),
                          style: TextStyle(
                            color: isDarkMode ? Colors.white60 : Colors.black45,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Teacher Section
                if (primaryTeacherId != null)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: _getTeacherInfo(primaryTeacherId),
                    builder: (context, snapshot) {
                      final teacherData = snapshot.data;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            // Round Profile Picture
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDarkMode ? Colors.white24 : Colors.black12,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: teacherData?['profile_picture'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: teacherData!['profile_picture'],
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey[300],
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Teacher Name
                            if (teacherData?['capoeira_name'] != null)
                              Text(
                                teacherData!['capoeira_name'],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                
                
                // Join/Leave Button for non-teachers
                if (!isTeacher)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isJoining ? null : (isMember ? _leaveGroup : _joinGroup),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMember ? Colors.grey : Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isJoining
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                isMember ? 'LEAVE GROUP' : 'JOIN GROUP',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                
                const Divider(height: 40),
                
                // Description
                if (group.description != null && group.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      group.description!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                // Weekly Schedule Section with inline Schedule Class button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scheduled Classes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          if (isTeacher || isAdmin)
                            TextButton(
                              onPressed: () => _showScheduleModal(context, group, 'class'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: const Size(0, 0),
                              ),
                              child: const Text(
                                'SCHEDULE CLASS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildCompactScheduleList(group, isDarkMode, isTeacher || isAdmin),
                    ],
                  ),
                ),
                
                const Divider(height: 40),
                
                // Next Roda Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Coming Roda',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '10/10/2024', // TODO: Get from actual data
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      if (isTeacher || isAdmin)
                        TextButton(
                          onPressed: () => _showScheduleModal(context, group, 'roda'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 0),
                          ),
                          child: const Text(
                            'SCHEDULE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Followers Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${group.memberIds.length} Followers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Tabs
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDarkMode ? Colors.white12 : Colors.black12,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 0 ? Colors.blue : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'ANNOUNCEMENTS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 0
                                    ? Colors.blue
                                    : (isDarkMode ? Colors.white54 : Colors.black54),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _selectedTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedTab == 1 ? Colors.blue : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                            ),
                            child: Text(
                              'MEDIA',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _selectedTab == 1
                                    ? Colors.blue
                                    : (isDarkMode ? Colors.white54 : Colors.black54),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab Content
                Container(
                  padding: const EdgeInsets.all(20),
                  child: _selectedTab == 0
                      ? _buildAnnouncementsTab(group, isDarkMode)
                      : _buildMediaTab(group, isDarkMode),
                ),
                
                // Delete Group Button for Admins
                if (isAdmin) ...[
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextButton(
                      onPressed: () => _deleteGroup(context, group),
                      child: Text(
                        'Delete Group',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
  
  Widget _buildCompactScheduleList(CapoeiraGroup group, bool isDarkMode, bool canEdit) {
    return Consumer(
      builder: (context, ref, child) {
        final schedulesAsync = ref.watch(groupSchedulesProvider(group.id));
        
        return schedulesAsync.when(
          data: (schedules) {
            if (schedules.isEmpty) {
              return Text(
                'No scheduled classes',
                style: TextStyle(
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                  fontSize: 14,
                ),
              );
            }
            
            // Sort by day of week and filter out rodas for this section
            final classSchedules = schedules.where((s) => s.eventType != EventType.roda).toList();
            classSchedules.sort((a, b) {
              final aDayOfWeek = a.dayOfWeek ?? 0;
              final bDayOfWeek = b.dayOfWeek ?? 0;
              return aDayOfWeek.compareTo(bDayOfWeek);
            });
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: classSchedules.map((schedule) {
                final dayIndex = schedule.dayOfWeek ?? 0;
                final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                final dayName = days[dayIndex.clamp(0, 6)];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40,
                        child: Text(
                          dayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Text(
                        '${schedule.startTime} - ${schedule.endTime}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (canEdit)
                        IconButton(
                          icon: Icon(
                            Icons.edit,
                            size: 18,
                            color: isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            // Edit schedule
                          },
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Error loading schedules', style: TextStyle(color: Colors.red)),
        );
      },
    );
  }
  
  Widget _buildScheduleSection(CapoeiraGroup group, bool isDarkMode, bool canEdit) {
    return Consumer(
      builder: (context, ref, child) {
        final schedulesAsync = ref.watch(groupSchedulesProvider(group.id));
        
        return schedulesAsync.when(
          data: (schedules) {
            if (schedules.isEmpty) {
              return Center(
                child: Text(
                  'No scheduled classes',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                    fontSize: 14,
                  ),
                ),
              );
            }
            
            // Sort by day of week
            schedules.sort((a, b) {
              final aDayOfWeek = a.dayOfWeek ?? 0;
              final bDayOfWeek = b.dayOfWeek ?? 0;
              return aDayOfWeek.compareTo(bDayOfWeek);
            });
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly Classes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                ...schedules.map((schedule) {
                  final dayIndex = schedule.dayOfWeek ?? 0;
                  final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
                  final dayName = days[dayIndex.clamp(0, 6)];
                  final isRoda = schedule.eventType == EventType.roda;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? (isRoda ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1))
                          : (isRoda ? Colors.orange.withOpacity(0.05) : Colors.blue.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRoda 
                            ? Colors.orange.withOpacity(0.3)
                            : Colors.blue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isRoda ? Icons.music_note : Icons.sports_martial_arts,
                          color: isRoda ? Colors.orange : Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              Text(
                                '${schedule.startTime} - ${schedule.endTime}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              if (schedule.location.isNotEmpty)
                                Text(
                                  schedule.location,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (schedule.price != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '\$${schedule.price!.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        if (canEdit) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 20,
                              color: isDarkMode ? Colors.white54 : Colors.black54,
                            ),
                            onPressed: () {
                              // Edit schedule
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(child: Text('Error loading schedules')),
        );
      },
    );
  }
  
  Widget _buildAnnouncementsTab(CapoeiraGroup group, bool isDarkMode) {
    if (group.announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.announcement_outlined,
              size: 48,
              color: isDarkMode ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'No announcements yet',
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: group.announcements.length,
      itemBuilder: (context, index) {
        final announcement = group.announcements[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                announcement.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                announcement.content,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, yyyy').format(announcement.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black54,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMediaTab(CapoeiraGroup group, bool isDarkMode) {
    // TODO: Implement actual media grid when available
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 48,
            color: isDarkMode ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            'No media yet',
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.black54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showScheduleModal(BuildContext context, CapoeiraGroup group, String type) {
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    final locationController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    String? selectedDay;
    double? locationLat;
    double? locationLng;
    bool showValidationErrors = false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.9,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
            children: [
              // Title at the top (below status bar)
              Container(
                padding: const EdgeInsets.only(top: 20, bottom: 10),
                child: Text(
                  type == 'roda' ? 'Schedule Roda' : 'Schedule Class',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day, Times and Price Row
                      Row(
                        children: [
                          // Day of Week (narrower)
                          SizedBox(
                            width: 65,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Day',
                                  style: FormTheme.labelStyle,
                                ),
                                const SizedBox(height: FormTheme.labelSpacing),
                                GestureDetector(
                        onTap: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext context) => Container(
                              height: 250,
                              color: CupertinoColors.systemBackground.resolveFrom(context),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          child: const Text('Cancel'),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                        CupertinoButton(
                                          padding: EdgeInsets.zero,
                                          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: CupertinoPicker(
                                      itemExtent: 32,
                                      onSelectedItemChanged: (int index) {
                                        setModalState(() {
                                          selectedDay = index.toString();
                                        });
                                      },
                                      children: const [
                                        Center(child: Text('Sunday')),
                                        Center(child: Text('Monday')),
                                        Center(child: Text('Tuesday')),
                                        Center(child: Text('Wednesday')),
                                        Center(child: Text('Thursday')),
                                        Center(child: Text('Friday')),
                                        Center(child: Text('Saturday')),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.tertiarySystemFill,
                            borderRadius: BorderRadius.circular(8),
                            border: showValidationErrors && selectedDay == null
                                ? Border.all(color: Colors.red, width: 1)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              selectedDay != null 
                                  ? ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][int.parse(selectedDay!)]
                                  : 'Day',
                              style: selectedDay != null ? FormTheme.inputTextStyle : FormTheme.placeholderStyle,
                            ),
                          ),
                        ),
                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                      
                          // Start Time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Start',
                                  style: FormTheme.labelStyle,
                                ),
                                const SizedBox(height: FormTheme.labelSpacing),
                                InkWell(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            builder: (BuildContext context) {
                              int selectedHour = 7;
                              int selectedMinute = 0;
                              String selectedPeriod = 'PM';
                              
                              return StatefulBuilder(
                                builder: (context, setTimeState) => Container(
                                  height: 300,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[300]!,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            const Text(
                                              'Select Start Time',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                final minute = selectedMinute.toString().padLeft(2, '0');
                                                setModalState(() {
                                                  startTimeController.text = '$selectedHour:$minute $selectedPeriod';
                                                });
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Selected value indicator
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            // Selection highlight bar
                                            Center(
                                              child: Container(
                                                height: 40,
                                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.blue.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // Hour picker
                                                SizedBox(
                                                  width: 70,
                                                  child: ListWheelScrollView.useDelegate(
                                                    itemExtent: 40,
                                                    physics: const FixedExtentScrollPhysics(),
                                                    onSelectedItemChanged: (index) {
                                                      setTimeState(() {
                                                        selectedHour = index + 1;
                                                      });
                                                    },
                                                    controller: FixedExtentScrollController(initialItem: 6),
                                                    childDelegate: ListWheelChildBuilderDelegate(
                                                      childCount: 12,
                                                      builder: (context, index) {
                                                        final isSelected = (index + 1) == selectedHour;
                                                        return Center(
                                                          child: Text(
                                                            '${index + 1}',
                                                            style: TextStyle(
                                                              fontSize: isSelected ? 24 : 20,
                                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                              color: isSelected ? Colors.blue : Colors.grey[600],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                                // Minute picker
                                                SizedBox(
                                                  width: 70,
                                                  child: ListWheelScrollView.useDelegate(
                                                    itemExtent: 40,
                                                    physics: const FixedExtentScrollPhysics(),
                                                    onSelectedItemChanged: (index) {
                                                      setTimeState(() {
                                                        selectedMinute = index * 5;
                                                      });
                                                    },
                                                    controller: FixedExtentScrollController(initialItem: 0),
                                                    childDelegate: ListWheelChildBuilderDelegate(
                                                      childCount: 12,
                                                      builder: (context, index) {
                                                        final minute = index * 5;
                                                        final isSelected = minute == selectedMinute;
                                                        return Center(
                                                          child: Text(
                                                            minute.toString().padLeft(2, '0'),
                                                            style: TextStyle(
                                                              fontSize: isSelected ? 24 : 20,
                                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                              color: isSelected ? Colors.blue : Colors.grey[600],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                // AM/PM picker
                                                SizedBox(
                                                  width: 60,
                                                  child: ListWheelScrollView(
                                                    itemExtent: 40,
                                                    physics: const FixedExtentScrollPhysics(),
                                                    onSelectedItemChanged: (index) {
                                                      setTimeState(() {
                                                        selectedPeriod = index == 0 ? 'AM' : 'PM';
                                                      });
                                                    },
                                                    controller: FixedExtentScrollController(initialItem: 1),
                                                    children: [
                                                      Center(
                                                        child: Text(
                                                          'AM',
                                                          style: TextStyle(
                                                            fontSize: selectedPeriod == 'AM' ? 24 : 20,
                                                            fontWeight: selectedPeriod == 'AM' ? FontWeight.bold : FontWeight.normal,
                                                            color: selectedPeriod == 'AM' ? Colors.blue : Colors.grey[600],
                                                          ),
                                                        ),
                                                      ),
                                                      Center(
                                                        child: Text(
                                                          'PM',
                                                          style: TextStyle(
                                                            fontSize: selectedPeriod == 'PM' ? 24 : 20,
                                                            fontWeight: selectedPeriod == 'PM' ? FontWeight.bold : FontWeight.normal,
                                                            color: selectedPeriod == 'PM' ? Colors.blue : Colors.grey[600],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: FormTheme.fieldPadding,
                          decoration: BoxDecoration(
                            color: CupertinoColors.tertiarySystemFill,
                            borderRadius: BorderRadius.circular(8),
                            border: showValidationErrors && startTimeController.text.isEmpty
                                ? Border.all(color: Colors.red, width: 1)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              startTimeController.text.isEmpty ? 'Time' : startTimeController.text,
                              style: startTimeController.text.isEmpty ? FormTheme.placeholderStyle : FormTheme.inputTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                      
                          // End Time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'End',
                                  style: FormTheme.labelStyle,
                                ),
                                const SizedBox(height: FormTheme.labelSpacing),
                                InkWell(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            builder: (BuildContext context) {
                              int selectedHour = 8;
                              int selectedMinute = 30;
                              String selectedPeriod = 'PM';
                              
                              return StatefulBuilder(
                                builder: (context, setTimeState) => Container(
                                  height: 300,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).scaffoldBackgroundColor,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[300]!,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            const Text(
                                              'Select End Time',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                final minute = selectedMinute.toString().padLeft(2, '0');
                                                setModalState(() {
                                                  endTimeController.text = '$selectedHour:$minute $selectedPeriod';
                                                });
                                                Navigator.pop(context);
                                              },
                                              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Selected value indicator
                                      Expanded(
                                        child: Stack(
                                          children: [
                                            // Selection highlight bar
                                            Center(
                                              child: Container(
                                                height: 40,
                                                margin: const EdgeInsets.symmetric(horizontal: 20),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.blue.withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // Hour picker
                                                SizedBox(
                                                  width: 70,
                                                  child: ListWheelScrollView.useDelegate(
                                                    itemExtent: 40,
                                                    physics: const FixedExtentScrollPhysics(),
                                                    onSelectedItemChanged: (index) {
                                                      setTimeState(() {
                                                        selectedHour = index + 1;
                                                      });
                                                    },
                                                    controller: FixedExtentScrollController(initialItem: 7),
                                                    childDelegate: ListWheelChildBuilderDelegate(
                                                      childCount: 12,
                                                      builder: (context, index) {
                                                        final isSelected = (index + 1) == selectedHour;
                                                        return Center(
                                                          child: Text(
                                                            '${index + 1}',
                                                            style: TextStyle(
                                                              fontSize: isSelected ? 24 : 20,
                                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                              color: isSelected ? Colors.blue : Colors.grey[600],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const Text(':', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                                                // Minute picker
                                                SizedBox(
                                                  width: 70,
                                                  child: ListWheelScrollView.useDelegate(
                                                    itemExtent: 40,
                                                    physics: const FixedExtentScrollPhysics(),
                                                    onSelectedItemChanged: (index) {
                                                      setTimeState(() {
                                                        selectedMinute = index * 5;
                                                      });
                                                    },
                                                    controller: FixedExtentScrollController(initialItem: 6),
                                                    childDelegate: ListWheelChildBuilderDelegate(
                                                      childCount: 12,
                                                      builder: (context, index) {
                                                        final minute = index * 5;
                                                        final isSelected = minute == selectedMinute;
                                                        return Center(
                                                          child: Text(
                                                            minute.toString().padLeft(2, '0'),
                                                            style: TextStyle(
                                                              fontSize: isSelected ? 24 : 20,
                                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                              color: isSelected ? Colors.blue : Colors.grey[600],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                // AM/PM picker
                                                SizedBox(
                                                  width: 60,
                                                  child: ListWheelScrollView(
                                                    itemExtent: 40,
                                                    physics: const FixedExtentScrollPhysics(),
                                                    onSelectedItemChanged: (index) {
                                                      setTimeState(() {
                                                        selectedPeriod = index == 0 ? 'AM' : 'PM';
                                                      });
                                                    },
                                                    controller: FixedExtentScrollController(initialItem: 1),
                                                    children: [
                                                      Center(
                                                        child: Text(
                                                          'AM',
                                                          style: TextStyle(
                                                            fontSize: selectedPeriod == 'AM' ? 24 : 20,
                                                            fontWeight: selectedPeriod == 'AM' ? FontWeight.bold : FontWeight.normal,
                                                            color: selectedPeriod == 'AM' ? Colors.blue : Colors.grey[600],
                                                          ),
                                                        ),
                                                      ),
                                                      Center(
                                                        child: Text(
                                                          'PM',
                                                          style: TextStyle(
                                                            fontSize: selectedPeriod == 'PM' ? 24 : 20,
                                                            fontWeight: selectedPeriod == 'PM' ? FontWeight.bold : FontWeight.normal,
                                                            color: selectedPeriod == 'PM' ? Colors.blue : Colors.grey[600],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        child: Container(
                          padding: FormTheme.fieldPadding,
                          decoration: BoxDecoration(
                            color: CupertinoColors.tertiarySystemFill,
                            borderRadius: BorderRadius.circular(8),
                            border: showValidationErrors && endTimeController.text.isEmpty
                                ? Border.all(color: Colors.red, width: 1)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              endTimeController.text.isEmpty ? 'Time' : endTimeController.text,
                              style: endTimeController.text.isEmpty ? FormTheme.placeholderStyle : FormTheme.inputTextStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Price
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == 'roda' ? 'Price' : 'Price',
                                  style: FormTheme.labelStyle,
                                ),
                                const SizedBox(height: FormTheme.labelSpacing),
                                CupertinoTextField(
                                  controller: priceController,
                                  keyboardType: TextInputType.number,
                                  padding: FormTheme.fieldPadding,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.tertiarySystemFill,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  placeholder: '\$',
                                  placeholderStyle: FormTheme.placeholderStyle,
                                  style: FormTheme.inputTextStyle,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: FormTheme.fieldSpacing),
                      
                      // Location with Google Places Autocomplete
                      const Text(
                        'Location',
                        style: FormTheme.labelStyle,
                      ),
                      const SizedBox(height: FormTheme.labelSpacing),
                      StyledGooglePlacesField(
                        controller: locationController,
                        showValidationError: showValidationErrors && (locationLat == null || locationLng == null),
                        onLocationSelected: (address, lat, lng) {
                          // Store the coordinates when a location is selected
                          setModalState(() {
                            locationLat = lat;
                            locationLng = lng;
                          });
                          if (lat != null && lng != null) {
                            print('Location selected: $address at ($lat, $lng)');
                          }
                        },
                      ),
                      
                      const SizedBox(height: FormTheme.fieldSpacing),
                      
                      // Description (optional)
                      const Text(
                        'Description (optional)',
                        style: FormTheme.labelStyle,
                      ),
                      const SizedBox(height: FormTheme.labelSpacing),
                      CupertinoTextField(
                        controller: descriptionController,
                        keyboardType: TextInputType.multiline,
                        maxLines: 3,
                        padding: FormTheme.fieldPadding,
                        decoration: BoxDecoration(
                          color: CupertinoColors.tertiarySystemFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        placeholder: 'Add any additional details...',
                        placeholderStyle: FormTheme.placeholderStyle,
                        style: FormTheme.inputTextStyle,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      // Note about recurrence
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This will create a recurring weekly ${type == "roda" ? "roda" : "class"} on ${selectedDay != null ? ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][int.parse(selectedDay!)] : "the selected day"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        color: type == 'roda' ? Colors.orange : Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                        onPressed: () async {
                          // Validate required fields
                          if (selectedDay == null || 
                              startTimeController.text.isEmpty || 
                              endTimeController.text.isEmpty || 
                              locationController.text.isEmpty ||
                              locationLat == null ||
                              locationLng == null) {
                            setModalState(() {
                              showValidationErrors = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please fill in all required fields'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          try {
                            // Parse times
                            final startTimeParts = startTimeController.text.split(' ');
                            final startTime = startTimeParts[0].split(':');
                            var startHour = int.parse(startTime[0]);
                            final startMinute = int.parse(startTime[1]);
                            if (startTimeParts[1] == 'PM' && startHour != 12) startHour += 12;
                            if (startTimeParts[1] == 'AM' && startHour == 12) startHour = 0;

                            final endTimeParts = endTimeController.text.split(' ');
                            final endTime = endTimeParts[0].split(':');
                            var endHour = int.parse(endTime[0]);
                            final endMinute = int.parse(endTime[1]);
                            if (endTimeParts[1] == 'PM' && endHour != 12) endHour += 12;
                            if (endTimeParts[1] == 'AM' && endHour == 12) endHour = 0;

                            // Get current user (teacher)
                            final currentUser = ref.read(currentUserProvider).value;
                            if (currentUser == null) {
                              throw Exception('User not found');
                            }

                            // Create schedule
                            final scheduleService = ref.read(supabaseScheduleServiceProvider);
                            await scheduleService.createSchedule(
                              groupId: group.id,
                              teacherId: currentUser.id,
                              name: type == 'roda' ? 'Weekly Roda' : 'Capoeira Class',
                              description: descriptionController.text.isNotEmpty ? descriptionController.text : null,
                              eventType: type,
                              latitude: locationLat!,
                              longitude: locationLng!,
                              locationName: locationController.text,
                              locationAddress: locationController.text,
                              timezone: 'America/New_York', // TODO: Get actual timezone
                              dayOfWeek: int.parse(selectedDay!),
                              startTime: DateTime(2024, 1, 1, startHour, startMinute),
                              endTime: DateTime(2024, 1, 1, endHour, endMinute),
                              price: priceController.text.isNotEmpty 
                                  ? double.tryParse(priceController.text) 
                                  : null,
                              maxStudents: null,
                            );

                            // Refresh schedules
                            ref.invalidate(groupSchedulesProvider(group.id));
                            
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${type == "roda" ? "Roda" : "Class"} scheduled successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to schedule: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Create',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}