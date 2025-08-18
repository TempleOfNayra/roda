import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
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
                expandedHeight: 200,
                pinned: true,
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
                                color: Colors.blue,
                                child: const Icon(
                                  Icons.group,
                                  size: 80,
                                  color: Colors.white,
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
                              child: const Icon(
                                Icons.group,
                                size: 80,
                                color: Colors.white,
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
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: Text(
                    group.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.black,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher Info Section
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Teacher Profile Picture
                          CircleAvatar(
                            radius: 35,
                            backgroundImage: group.teacherProfilePicture != null
                                ? CachedNetworkImageProvider(group.teacherProfilePicture!)
                                : null,
                            backgroundColor: Colors.grey[300],
                            child: group.teacherProfilePicture == null
                                ? Text(
                                    group.teacherName?.substring(0, 1).toUpperCase() ?? 'T',
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          // Teacher Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.teacherName ?? 'Teacher',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Group Leader',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (group.adminIds.contains(group.createdBy)) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.purple,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ADMIN',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (group.location != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          group.location!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Join/Leave Button
                          if (!isTeacher)
                            ElevatedButton(
                              onPressed: _isJoining 
                                  ? null 
                                  : (isMember ? _leaveGroup : _joinGroup),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isMember ? Colors.grey : Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
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
                                      isMember ? 'LEAVE' : 'JOIN',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                        ],
                      ),
                    ),
                    
                    // Group Stats
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        border: Border(
                          top: BorderSide(color: Colors.grey[300]!),
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(
                            '${group.memberIds.length}',
                            'Members',
                            Icons.people,
                          ),
                          _buildStatItem(
                            '${group.teacherIds.length}',
                            'Teachers',
                            Icons.school,
                          ),
                          if (group.branch != null)
                            _buildStatItem(
                              group.branch!,
                              'Branch',
                              Icons.account_tree,
                            ),
                        ],
                      ),
                    ),
                    
                    // Description Section
                    if (group.description != null) ...[
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'About',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              group.description!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Announcements Section
                    Padding(
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
  
  void _showEditGroupDialog(BuildContext context, CapoeiraGroup group) {
    final nameController = TextEditingController(text: group.name);
    final branchController = TextEditingController(text: group.branch);
    final locationController = TextEditingController(text: group.location);
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
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Location'),
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
                'location': locationController.text.isEmpty ? null : locationController.text,
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
}