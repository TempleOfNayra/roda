import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/teacher/providers/supabase_schedule_providers.dart';
import 'package:roda/application/group_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return SafeScaffold(
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
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAppBar(context, ref),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data'));
          }
          
          final registeredClasses = ref.watch(userRegisteredClassesProvider(user.id));
          
          return SingleChildScrollView(
            child: Column(
              children: [
                // Condensed profile info at top
                Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      backgroundImage: user.profilePictureUrl != null 
                          ? NetworkImage(user.profilePictureUrl!) 
                          : null,
                      child: user.profilePictureUrl == null
                          ? Text(
                              user.capoeiraName.isNotEmpty 
                                  ? user.capoeiraName[0].toUpperCase() 
                                  : 'U',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            )
                          : null,
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
              
              // Groups Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Groups:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (user.role == UserRole.teacher)
                      ElevatedButton.icon(
                        onPressed: () => context.push(Routes.createGroup),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Create Group'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                  ],
                ),
              ),
              
              // Groups List
              Consumer(
                builder: (context, ref, child) {
                  final groupsAsync = ref.watch(userGroupsProvider);
                  
                  return groupsAsync.when(
                    data: (groups) {
                      if (groups.isEmpty) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.group_outlined,
                                  size: 48,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user.role == UserRole.teacher 
                                      ? 'No groups yet. Create your first group!' 
                                      : 'You haven\'t joined any groups yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      
                      return Column(
                        children: groups.map((group) {
                          final isAdmin = group.adminIds.contains(user.id);
                          final isTeacher = group.teacherIds.contains(user.id);
                          
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Card(
                              elevation: 1,
                              child: InkWell(
                                onTap: () => context.push('${Routes.group}/${group.id}'),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Group Avatar
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundImage: group.headerImageUrl != null
                                            ? CachedNetworkImageProvider(group.headerImageUrl!)
                                            : null,
                                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                                        child: group.headerImageUrl == null
                                            ? Text(
                                                group.displayName.isNotEmpty 
                                                    ? group.displayName[0].toUpperCase()
                                                    : 'G',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(context).primaryColor,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      // Group Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    group.displayName,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                if (isAdmin)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Text(
                                                      'ADMIN',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                else if (isTeacher)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Text(
                                                      'TEACHER',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.location_on,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  group.city,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  Icons.people,
                                                  size: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${group.memberIds.length} members',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Arrow
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey[400],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading groups: $error'),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 16),
              
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
              registeredClasses.when(
                data: (classes) {
                  if (classes.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
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
                            'Find and register for classes near you',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => context.push(Routes.map),
                            icon: const Icon(Icons.map),
                            label: const Text('Browse Classes'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return Column(
                    children: classes.take(5).map((classData) {
                      // TODO: Re-implement _buildClassCard with new data structure
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Card(
                          child: ListTile(
                            title: Text('Class ${classes.indexOf(classData) + 1}'),
                            subtitle: const Text('Class details'),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Error loading classes: $error'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  
  Widget _buildBottomAppBar(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isTeacher = user?.role == UserRole.teacher || 
                     (user?.teachingGroupIds.isNotEmpty ?? false);
    
    return BottomAppBar(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home button
            InkWell(
              onTap: () => context.go(Routes.main),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.home),
                    Text(
                      'Home',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            // Map button
            InkWell(
              onTap: () => context.push(Routes.map),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map),
                    Text(
                      'Map',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            // Calendar/Schedule button
            InkWell(
              onTap: () {
                // TODO: Navigate to schedule/calendar view
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schedule view coming soon'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today),
                    Text(
                      'Schedule',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            // Groups button
            InkWell(
              onTap: () {
                // TODO: Navigate to groups view
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Groups view coming soon'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group),
                    Text(
                      'Groups',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            // Teacher Dashboard (if teacher) or Settings
            if (isTeacher)
              InkWell(
                onTap: () => context.push(Routes.teacherDashboard),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school),
                      Text(
                        'Teach',
                        style: TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              )
            else
              InkWell(
                onTap: () => context.push(Routes.editProfile),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings),
                      Text(
                        'Settings',
                        style: TextStyle(fontSize: 10),
                      ),
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