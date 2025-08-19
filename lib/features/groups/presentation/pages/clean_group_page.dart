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
                // Clean Header - No blur, just solid info
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
                      if (group.branch != null)
                        Text(
                          group.branch!,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      
                      // City
                      if (group.city != null)
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
                
                // Action Buttons Section
                if (isTeacher || isAdmin)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        // Schedule Class Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showScheduleModal(context, group, 'class'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'SCHEDULE CLASS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        
                        // Schedule Roda Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _showScheduleModal(context, group, 'roda'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'SCHEDULE RODA',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                
                const SizedBox(height: 20),
                
                // Description
                if (group.description != null && group.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          group.description!,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black87,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 30),
                
                // Weekly Schedule Section (always visible)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildScheduleSection(group, isDarkMode, isTeacher || isAdmin),
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
                
                // Next Roda Section
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.music_note,
                        color: Colors.orange,
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Next Roda',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'October 10, 2024', // TODO: Get from actual data
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
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
                  Text(
                    type == 'roda' ? 'Schedule Roda' : 'Schedule Class',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Create schedule
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Form fields would go here
                    Text('Schedule form for ${type == "roda" ? "Roda" : "Class"}'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}