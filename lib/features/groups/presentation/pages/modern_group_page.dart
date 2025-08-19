import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/teacher/providers/supabase_schedule_providers.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'dart:ui';

class ModernGroupPage extends ConsumerStatefulWidget {
  final String groupId;
  
  const ModernGroupPage({
    super.key,
    required this.groupId,
  });
  
  @override
  ConsumerState<ModernGroupPage> createState() => _ModernGroupPageState();
}

class _ModernGroupPageState extends ConsumerState<ModernGroupPage> {
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
  
  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider).value;
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return CupertinoPageScaffold(
      backgroundColor: isDarkMode ? Colors.black : CupertinoColors.systemBackground,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.9) : CupertinoColors.white.withOpacity(0.9),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.back,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () => context.pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: Icon(
            CupertinoIcons.ellipsis,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          onPressed: () {
            // Show options menu
          },
        ),
      ),
      child: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }
          
          final isMember = group.memberIds.contains(currentUser?.id);
          final isTeacher = group.teacherIds.contains(currentUser?.id);
          final isAdmin = group.adminIds.contains(currentUser?.id);
          final primaryTeacherId = group.teacherIds.isNotEmpty ? group.teacherIds.first : null;
          
          return CustomScrollView(
            slivers: [
              // Header with background image
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Background image with blur
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        image: group.headerImageUrl != null
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(group.headerImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient: group.headerImageUrl == null
                            ? LinearGradient(
                                colors: [Colors.blue.shade400, Colors.blue.shade600],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                      ),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.3),
                                Colors.black.withOpacity(0.6),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Group Info Overlay
                    Positioned(
                      bottom: 20,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Group Name
                          Text(
                            group.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // Affiliation/Branch
                          if (group.branch != null)
                            Text(
                              group.branch!,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          
                          // City
                          if (group.city != null)
                            Text(
                              group.city!.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                                letterSpacing: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Content
              SliverToBoxAdapter(
                child: Container(
                  color: isDarkMode ? Colors.black : Colors.white,
                  child: Column(
                    children: [
                      // Teacher Info Section
                      if (primaryTeacherId != null)
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _getTeacherInfo(primaryTeacherId),
                          builder: (context, snapshot) {
                            final teacherData = snapshot.data;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Column(
                                children: [
                                  // Teacher Profile Picture (Round)
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
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
                                                CupertinoIcons.person_fill,
                                                size: 40,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Teacher Name
                                  Text(
                                    teacherData?['capoeira_name'] ?? 'Teacher',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      
                      // Schedule Buttons Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            // Schedule Class Button
                            if (isTeacher || isAdmin)
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  color: CupertinoColors.activeBlue,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.calendar_badge_plus, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Schedule Class',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onPressed: () => _showScheduleModal(context, group, 'class'),
                                ),
                              ),
                            
                            if ((isTeacher || isAdmin) && !isMember)
                              const SizedBox(width: 8),
                            
                            // Schedule Roda Button
                            if (isTeacher || isAdmin)
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(8),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(CupertinoIcons.music_note, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Schedule Roda',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onPressed: () => _showScheduleModal(context, group, 'roda'),
                                ),
                              ),
                            
                            // Join/Leave Button (for non-teachers)
                            if (!isTeacher)
                              Expanded(
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  color: isMember ? CupertinoColors.systemGrey : CupertinoColors.activeBlue,
                                  borderRadius: BorderRadius.circular(8),
                                  child: _isJoining
                                      ? const CupertinoActivityIndicator(color: Colors.white)
                                      : Text(
                                          isMember ? 'Leave' : 'Join',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                  onPressed: _isJoining ? null : (isMember ? _leaveGroup : _joinGroup),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Description
                      if (group.description != null && group.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            group.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 20),
                      
                      // Weekly Schedule
                      _buildWeeklySchedule(group, isDarkMode, isTeacher || isAdmin),
                      
                      const SizedBox(height: 20),
                      
                      // Next Roda
                      _buildNextRoda(group, isDarkMode),
                      
                      const SizedBox(height: 20),
                      
                      // Followers Section
                      _buildFollowersSection(group, isDarkMode),
                      
                      const SizedBox(height: 20),
                      
                      // Tab Bar
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!,
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  children: [
                                    Icon(
                                      CupertinoIcons.bell,
                                      color: _selectedTab == 0
                                          ? CupertinoColors.activeBlue
                                          : (isDarkMode ? Colors.grey[600] : Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'ANNOUNCEMENTS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTab == 0
                                            ? CupertinoColors.activeBlue
                                            : (isDarkMode ? Colors.grey[600] : Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () => setState(() => _selectedTab = 0),
                              ),
                            ),
                            Expanded(
                              child: CupertinoButton(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  children: [
                                    Icon(
                                      CupertinoIcons.photo,
                                      color: _selectedTab == 1
                                          ? CupertinoColors.activeBlue
                                          : (isDarkMode ? Colors.grey[600] : Colors.grey),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'MEDIA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedTab == 1
                                            ? CupertinoColors.activeBlue
                                            : (isDarkMode ? Colors.grey[600] : Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                                onPressed: () => setState(() => _selectedTab = 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Tab Content
                      Container(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.3,
                        ),
                        child: _selectedTab == 0
                            ? _buildAnnouncementsTab(group, isDarkMode)
                            : _buildMediaTab(group, isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
  
  Widget _buildWeeklySchedule(CapoeiraGroup group, bool isDarkMode, bool canEdit) {
    return Consumer(
      builder: (context, ref, child) {
        final schedulesAsync = ref.watch(groupSchedulesProvider(group.id));
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Scheduled Classes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            schedulesAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No scheduled classes',
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[600] : Colors.grey,
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
                  children: schedules.map((schedule) {
                    final dayIndex = schedule.dayOfWeek ?? 0;
                    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                    final dayName = days[dayIndex.clamp(0, 6)];
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              dayName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            '${schedule.startTime} - ${schedule.endTime}',
                            style: TextStyle(
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (canEdit)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              child: Icon(
                                CupertinoIcons.pencil,
                                size: 16,
                                color: isDarkMode ? Colors.grey[600] : Colors.grey,
                              ),
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
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CupertinoActivityIndicator(),
                ),
              ),
              error: (error, _) => Center(
                child: Text('Error loading schedules'),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildNextRoda(CapoeiraGroup group, bool isDarkMode) {
    return Padding(
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
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            child: const Text(
              'View Schedule',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              // Navigate to roda schedule
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildFollowersSection(CapoeiraGroup group, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${group.memberIds.length} Followers',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Show first 3 member profile pics
              ...List.generate(
                group.memberIds.length > 3 ? 3 : group.memberIds.length,
                (index) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? Colors.black : Colors.white,
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Container(
                      color: Colors.grey[300],
                      child: Icon(
                        CupertinoIcons.person_fill,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ),
              ),
              if (group.memberIds.length > 3)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                  ),
                  child: Center(
                    child: Text(
                      '+${group.memberIds.length - 3}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnnouncementsTab(CapoeiraGroup group, bool isDarkMode) {
    if (group.announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                CupertinoIcons.bell_slash,
                size: 48,
                color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No announcements yet',
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[600] : Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: group.announcements.length,
      itemBuilder: (context, index) {
        final announcement = group.announcements[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
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
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('MMM d, yyyy').format(announcement.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.grey[600] : Colors.grey,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildMediaTab(CapoeiraGroup group, bool isDarkMode) {
    // TODO: Implement media grid
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              CupertinoIcons.photo,
              size: 48,
              color: isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No media yet',
              style: TextStyle(
                color: isDarkMode ? Colors.grey[600] : Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showScheduleModal(BuildContext context, CapoeiraGroup group, String type) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.systemGrey5,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    type == 'roda' ? 'Schedule Roda' : 'Schedule Class',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onPressed: () {
                      // Create schedule
                      Navigator.pop(context);
                    },
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
                    Text('Schedule form for $type'),
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