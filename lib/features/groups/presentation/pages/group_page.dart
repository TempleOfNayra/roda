import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/groups/providers/group_providers.dart';
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
      // Add user to group members
      await FirebaseFirestore.instance
          .collection('capoeira_groups')
          .doc(widget.groupId)
          .update({
        'memberIds': FieldValue.arrayUnion([user.id]),
      });
      
      // Add group to user's joined groups
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({
        'joinedGroupIds': FieldValue.arrayUnion([widget.groupId]),
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
      // Remove user from group members
      await FirebaseFirestore.instance
          .collection('capoeira_groups')
          .doc(widget.groupId)
          .update({
        'memberIds': FieldValue.arrayRemove([user.id]),
      });
      
      // Remove group from user's joined groups
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.id)
          .update({
        'joinedGroupIds': FieldValue.arrayRemove([widget.groupId]),
      });
      
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
          
          return CustomScrollView(
            slivers: [
              // Custom App Bar with Header Image
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
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
                                Text(
                                  'Group Leader',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
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
}