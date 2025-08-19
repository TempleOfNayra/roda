import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/models/schedule_template.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/features/teacher/providers/supabase_schedule_providers.dart';
import 'package:roda/features/teacher/presentation/widgets/google_places_address_field.dart';
import 'package:roda/application/group_controller.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:intl/intl.dart';

class GroupPage extends ConsumerStatefulWidget {
  final String groupId;
  
  const GroupPage({
    super.key,
    required this.groupId,
  });
  
  @override
  ConsumerState<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends ConsumerState<GroupPage> {
  bool _isJoining = false;
  
  Future<void> _joinGroup() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    
    setState(() => _isJoining = true);
    
    try {
      // Add user to group using Supabase
      await SupabaseConfig.client
          .from('group_members')
          .insert({
            'group_id': widget.groupId,
            'user_id': user.id,
            'role': 'member',
          });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the group!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }
  
  Future<void> _leaveGroup() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group?'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Remove user from group using Supabase
      await SupabaseConfig.client
          .from('group_members')
          .delete()
          .eq('group_id', widget.groupId)
          .eq('user_id', user.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have left the group'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _deleteGroup(BuildContext context, CapoeiraGroup group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this group?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Group: ${group.displayName}'),
            const SizedBox(height: 16),
            const Text(
              'This action cannot be undone. All group data, members, and announcements will be permanently deleted.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      final groupController = ref.read(groupControllerProvider);
      await groupController.deleteGroup(widget.groupId);
      
      // Invalidate the user groups provider to force refresh
      ref.invalidate(userGroupsProvider);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate to profile page instead of my groups
        context.go(Routes.profile);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete group: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider).value;
    
    return SafeScaffold(
      body: groupAsync.when(
        data: (group) {
          if (group == null) {
            return const Center(child: Text('Group not found'));
          }
          
          final isMember = group.memberIds.contains(currentUser?.id);
          final isTeacher = group.teacherIds.contains(currentUser?.id);
          final isAdmin = group.adminIds.contains(currentUser?.id);
          
          return CustomScrollView(
            slivers: [
              // Custom App Bar with Header Image
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: Colors.white,
                elevation: 0,
                actions: isAdmin ? [
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) async {
                      switch (value) {
                        case 'manage_members':
                          _showManageMembersDialog(context, group, currentUser!.id);
                          break;
                        case 'manage_teachers':
                          _showManageTeachersDialog(context, group, currentUser!.id);
                          break;
                        case 'edit_group':
                          _showEditGroupDialog(context, group);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'manage_members',
                        child: Row(
                          children: [
                            Icon(Icons.people, size: 20),
                            SizedBox(width: 8),
                            Text('Manage Members'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'manage_teachers',
                        child: Row(
                          children: [
                            Icon(Icons.school, size: 20),
                            SizedBox(width: 8),
                            Text('Manage Teachers'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit_group',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Edit Group Info'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Header Image
                      group.headerImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: group.headerImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue.shade400,
                                      Colors.blue.shade700,
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade700,
                                  ],
                                ),
                              ),
                            ),
                      // Gradient Overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                      // Group Info Overlay
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Group Name
                            Text(
                              group.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // City
                            if (group.city != null)
                              Text(
                                group.city!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 16,
                                ),
                              ),
                            // Teacher Names
                            FutureBuilder<List<String>>(
                              future: _getTeacherNames(group.teacherIds),
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                                  return Text(
                                    'by ${snapshot.data!.join(", ")}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                            const SizedBox(height: 8),
                            // Stats Row
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.group, color: Colors.white, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${group.memberIds.length} members',
                                        style: const TextStyle(color: Colors.white, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                if (group.teacherIds.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.school, color: Colors.white, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${group.teacherIds.length} teachers',
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Join/Leave Button (if not teacher)
                        if (!isTeacher)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isJoining 
                                    ? null 
                                    : (isMember ? _leaveGroup : _joinGroup),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isMember ? Colors.grey : Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
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
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        
                        // Description (if exists)
                        if (group.description != null && group.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Text(
                              group.description!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        
                        // Divider
                        if (group.description != null && group.description!.isNotEmpty)
                          Divider(height: 1, color: Colors.grey[200]),
                        
                        // Weekly Schedule Section (compact)
                        _buildCompactScheduleSection(group),
                        
                        // Schedule New Class Form for Teachers/Admins (compact)
                        if (isTeacher || isAdmin) ...[
                          Divider(height: 1, color: Colors.grey[200]),
                          _buildCompactScheduleForm(group),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              // Announcements Section
              SliverToBoxAdapter(
                child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Announcements',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (isTeacher)
                                IconButton(
                                  onPressed: () {
                                    // TODO: Add announcement
                                  },
                                  icon: const Icon(Icons.add_circle),
                                  color: Colors.blue,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (group.announcements.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.announcement_outlined,
                                      size: 48,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'No announcements yet',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ...group.announcements.map((announcement) => 
                              _buildAnnouncementCard(announcement),
                            ),
                        ],
                      ),
                    ),
              ),
              
              // Delete Group Button for Admins
              if (isAdmin)
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: TextButton.icon(
                            onPressed: () => _deleteGroup(context, group),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            label: const Text(
                              'Delete Group',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
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
  
  Widget _buildStatItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnnouncementCard(GroupAnnouncement announcement) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (announcement.isPinned)
                  const Icon(
                    Icons.push_pin,
                    size: 16,
                    color: Colors.orange,
                  ),
                if (announcement.isPinned)
                  const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    announcement.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              announcement.content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  announcement.authorName ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Text(' • '),
                Text(
                  dateFormat.format(announcement.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  void _showManageMembersDialog(BuildContext context, CapoeiraGroup group, String adminId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Members'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: SupabaseConfig.client
                .from('group_members')
                .select('users(*)')
                .eq('group_id', widget.groupId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final members = snapshot.data!;
              
              return ListView.builder(
                shrinkWrap: true,
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  final memberId = member['users']['id'];
                  final memberData = member['users'] as Map<String, dynamic>;
                  final isCurrentUserAdmin = memberId == adminId;
                  final isMemberAdmin = group.adminIds.contains(memberId);
                  final isMemberTeacher = group.teacherIds.contains(memberId);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        memberData['capoeiraName']?.substring(0, 1).toUpperCase() ?? 'U',
                      ),
                    ),
                    title: Text(memberData['capoeiraName'] ?? 'Unknown'),
                    subtitle: Row(
                      children: [
                        if (isMemberAdmin)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Admin',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        if (isMemberTeacher)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Teacher',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    trailing: !isCurrentUserAdmin ? PopupMenuButton<String>(
                      onSelected: (value) async {
                        final groupService = ref.read(supabaseGroupServiceProvider);
                        switch (value) {
                          case 'make_teacher':
                            await groupService.addTeacherToGroup(widget.groupId, memberId);
                            break;
                          case 'remove_teacher':
                            await groupService.removeTeacherFromGroup(widget.groupId, memberId);
                            break;
                          case 'make_admin':
                            await groupService.addAdminToGroup(widget.groupId, memberId);
                            break;
                          case 'remove_member':
                            await groupService.removeMemberFromGroup(widget.groupId, memberId);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (!isMemberTeacher)
                          const PopupMenuItem(
                            value: 'make_teacher',
                            child: Text('Make Teacher'),
                          ),
                        if (isMemberTeacher && !isMemberAdmin)
                          const PopupMenuItem(
                            value: 'remove_teacher',
                            child: Text('Remove Teacher Role'),
                          ),
                        if (!isMemberAdmin)
                          const PopupMenuItem(
                            value: 'make_admin',
                            child: Text('Make Admin'),
                          ),
                        if (!isMemberAdmin)
                          const PopupMenuItem(
                            value: 'remove_member',
                            child: Text('Remove from Group'),
                          ),
                      ],
                    ) : null,
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  void _showManageTeachersDialog(BuildContext context, CapoeiraGroup group, String adminId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Teachers'),
        content: const Text('Select members to add or remove as teachers'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Future<List<String>> _getTeacherNames(List<String> teacherIds) async {
    if (teacherIds.isEmpty) return [];
    
    try {
      final response = await SupabaseConfig.client
          .from('users')
          .select('capoeira_name')
          .inFilter('id', teacherIds);
      
      return (response as List)
          .map((user) => user['capoeira_name'] as String? ?? 'Unknown')
          .toList();
    } catch (e) {
      return [];
    }
  }
  
  void _showEditGroupDialog(BuildContext context, CapoeiraGroup group) {
    final nameController = TextEditingController(text: group.name);
    final branchController = TextEditingController(text: group.branch);
    final cityController = TextEditingController(text: group.city);
    final descriptionController = TextEditingController(text: group.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Info'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Group Name'),
              ),
              TextField(
                controller: branchController,
                decoration: const InputDecoration(labelText: 'Branch/Affiliation'),
              ),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final groupService = ref.read(supabaseGroupServiceProvider);
              await groupService.updateGroupDetails(widget.groupId, {
                'name': nameController.text,
                'branch': branchController.text.isEmpty ? null : branchController.text,
                'city': cityController.text.isEmpty ? null : cityController.text,
                'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                'displayName': CapoeiraGroup.createDisplayName(
                  nameController.text,
                  branchController.text.isEmpty ? null : branchController.text,
                ),
              });
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Group info updated')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScheduledClassesSection(CapoeiraGroup group) {
    return Consumer(
      builder: (context, ref, child) {
        final schedulesAsync = ref.watch(groupSchedulesProvider(group.id));
        
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Schedule',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              schedulesAsync.when(
                data: (schedules) {
                  if (schedules.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 36,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No weekly schedules yet',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Days of week for sorting
                  final daysOrder = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
                  
                  // Sort schedules by day of week (handle nulls)
                  schedules.sort((a, b) {
                    final aDayOfWeek = a.dayOfWeek ?? 0;
                    final bDayOfWeek = b.dayOfWeek ?? 0;
                    return aDayOfWeek.compareTo(bDayOfWeek);
                  });
                  
                  return Column(
                    children: schedules.map((schedule) {
                      final dayIndex = schedule.dayOfWeek ?? 0;
                      final dayName = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'][dayIndex.clamp(0, 6)];
                      final isRoda = schedule.eventType == EventType.roda;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isRoda ? Colors.orange.shade200 : Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Event type icon
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isRoda ? Colors.orange.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                isRoda ? Icons.music_note : Icons.sports_martial_arts,
                                color: isRoda ? Colors.orange : Colors.blue,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            
                            // Day and time
                            Expanded(
                              child: Row(
                                children: [
                                  // Day of week
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      dayName.substring(0, 3).toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  
                                  // Time
                                  Text(
                                    '${schedule.startTime} - ${schedule.endTime}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // Location (abbreviated)
                                  Expanded(
                                    child: Text(
                                      schedule.location.split(',').first,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Price
                            if (schedule.price != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '\$${schedule.price!.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => Center(
                  child: Text(
                    'Error loading schedules',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildScheduleClassForm(CapoeiraGroup group) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: _ScheduleClassForm(group: group),
    );
  }
  
  Widget _buildCompactScheduleSection(CapoeiraGroup group) {
    return Consumer(
      builder: (context, ref, child) {
        final schedulesAsync = ref.watch(groupSchedulesProvider(group.id));
        
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Weekly Schedule',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              
              schedulesAsync.when(
                data: (schedules) {
                  if (schedules.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'No weekly schedules yet',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  // Sort schedules by day of week (handle nulls)
                  schedules.sort((a, b) {
                    final aDayOfWeek = a.dayOfWeek ?? 0;
                    final bDayOfWeek = b.dayOfWeek ?? 0;
                    return aDayOfWeek.compareTo(bDayOfWeek);
                  });
                  
                  return Column(
                    children: schedules.map((schedule) {
                      final dayIndex = schedule.dayOfWeek ?? 0;
                      final dayName = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'][dayIndex.clamp(0, 6)];
                      final isRoda = schedule.eventType == EventType.roda;
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isRoda ? Colors.orange.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            // Day
                            SizedBox(
                              width: 35,
                              child: Text(
                                dayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: isRoda ? Colors.orange.shade700 : Colors.blue.shade700,
                                ),
                              ),
                            ),
                            
                            // Icon
                            Icon(
                              isRoda ? Icons.music_note : Icons.sports_martial_arts,
                              color: isRoda ? Colors.orange : Colors.blue,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            
                            // Time
                            Text(
                              '${schedule.startTime} - ${schedule.endTime}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                              ),
                            ),
                            
                            const Spacer(),
                            
                            // Price
                            if (schedule.price != null)
                              Text(
                                '\$${schedule.price!.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, _) => Center(
                  child: Text(
                    'Error loading schedules',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildCompactScheduleForm(CapoeiraGroup group) {
    return ExpansionTile(
      title: const Text(
        'Add New Class',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      leading: const Icon(Icons.add_circle, color: Colors.blue, size: 20),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _ScheduleClassForm(group: group),
        ),
      ],
    );
  }
}

// Schedule Class Form Widget
class _ScheduleClassForm extends ConsumerStatefulWidget {
  final CapoeiraGroup group;
  
  const _ScheduleClassForm({
    required this.group,
  });
  
  @override
  ConsumerState<_ScheduleClassForm> createState() => _ScheduleClassFormState();
}

class _ScheduleClassFormState extends ConsumerState<_ScheduleClassForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _priceController = TextEditingController();
  final _maxStudentsController = TextEditingController();
  
  EventType _eventType = EventType.class_;
  int _selectedDayOfWeek = 1; // Monday
  TimeOfDay _startTime = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 30);
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _locationAddressController.dispose();
    _priceController.dispose();
    _maxStudentsController.dispose();
    super.dispose();
  }
  
  Future<void> _selectTime(bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }
  
  Future<void> _createSchedule() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('No user logged in');
      
      final scheduleService = ref.read(supabaseScheduleServiceProvider);
      
      // Create DateTime objects for time (date doesn't matter, only time is used)
      final now = DateTime.now();
      final startDateTime = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
      final endDateTime = DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);
      
      // Update to create 4 months (16 weeks) of classes
      await scheduleService.createSchedule(
        groupId: widget.group.id,
        teacherId: user.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        eventType: _eventType == EventType.class_ ? 'class' : 'roda',
        latitude: _latitude!,
        longitude: _longitude!,
        locationName: _locationNameController.text.trim(),
        locationAddress: _locationAddressController.text.trim(),
        timezone: 'America/Los_Angeles', // TODO: Get from user's location
        dayOfWeek: _selectedDayOfWeek,
        startTime: startDateTime,
        endTime: endDateTime,
        price: _priceController.text.isEmpty ? null : double.parse(_priceController.text),
        maxStudents: _maxStudentsController.text.isEmpty ? null : int.parse(_maxStudentsController.text),
      );
      
      // Refresh the schedules
      ref.invalidate(groupSchedulesProvider(widget.group.id));
      
      // Clear form
      _nameController.clear();
      _descriptionController.clear();
      _locationNameController.clear();
      _locationAddressController.clear();
      _priceController.clear();
      _maxStudentsController.clear();
      setState(() {
        _latitude = null;
        _longitude = null;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class schedule created successfully! Classes have been generated for the next 4 months.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e, stackTrace) {
      print('[GroupPage] Error creating schedule: $e');
      print('[GroupPage] Stack trace: $stackTrace');
      
      // Extract more useful error message
      String errorMessage = 'Failed to create schedule';
      if (e.toString().contains('Exception:')) {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      } else {
        errorMessage = '$errorMessage: $e';
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Schedule New Class',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Class Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Class Name *',
                  hintText: 'e.g., Beginner Class, Open Roda',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a class name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Event Type
              const Text('Event Type *'),
              Row(
                children: [
                  Radio<EventType>(
                    value: EventType.class_,
                    groupValue: _eventType,
                    onChanged: (value) => setState(() => _eventType = value!),
                  ),
                  const Text('Class'),
                  const SizedBox(width: 16),
                  Radio<EventType>(
                    value: EventType.roda,
                    groupValue: _eventType,
                    onChanged: (value) => setState(() => _eventType = value!),
                  ),
                  const Text('Roda'),
                ],
              ),
              const SizedBox(height: 16),
              
              // Day of Week (PostgreSQL DOW: 0=Sunday, 1=Monday, ..., 6=Saturday)
              DropdownButtonFormField<int>(
                value: _selectedDayOfWeek,
                decoration: const InputDecoration(
                  labelText: 'Day of Week *',
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sunday')),
                  DropdownMenuItem(value: 1, child: Text('Monday')),
                  DropdownMenuItem(value: 2, child: Text('Tuesday')),
                  DropdownMenuItem(value: 3, child: Text('Wednesday')),
                  DropdownMenuItem(value: 4, child: Text('Thursday')),
                  DropdownMenuItem(value: 5, child: Text('Friday')),
                  DropdownMenuItem(value: 6, child: Text('Saturday')),
                ],
                onChanged: (value) => setState(() => _selectedDayOfWeek = value!),
              ),
              const SizedBox(height: 16),
              
              // Time Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start Time *',
                        ),
                        child: Text(_startTime.format(context)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'End Time *',
                        ),
                        child: Text(_endTime.format(context)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Location
              GooglePlacesAddressField(
                controller: _locationAddressController,
                onLocationSelected: (address, lat, lng) {
                  setState(() {
                    _locationNameController.text = address.split(',').first; // Use first part as name
                    _locationAddressController.text = address;
                    _latitude = lat;
                    _longitude = lng;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Price (optional)
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Price (optional)',
                  prefixText: '\$',
                  hintText: '15.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid price';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Max Students (optional)
              TextFormField(
                controller: _maxStudentsController,
                decoration: const InputDecoration(
                  labelText: 'Max Students (optional)',
                  hintText: '20',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (int.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Description (optional)
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Class details, what to bring, etc.',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              
              Text(
                'This will create weekly classes for the next 4 months',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createSchedule,
                  icon: const Icon(Icons.add_circle),
                  label: const Text(
                    'Create Class Schedule',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}