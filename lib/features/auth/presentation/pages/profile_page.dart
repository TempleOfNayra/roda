import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/application/group_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roda/features/groups/presentation/pages/create_edit_group_modal.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:roda/core/theme/roda_theme.dart';
import 'package:roda/core/widgets/user_avatar.dart';
import 'package:roda/core/widgets/group_avatar.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    
    return CupertinoPageScaffold(
      backgroundColor: RodaColors.background,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: RodaColors.surface,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.go(Routes.main),
          child: const Icon(CupertinoIcons.back),
        ),
        middle: const Text('My Profile'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Show teacher dashboard button if user is a teacher or has teaching groups
            Consumer(
              builder: (context, ref, child) {
                final user = ref.watch(currentUserProvider).value;
                final isTeacher = user?.role == UserRole.teacher || 
                                 (user?.teachingGroupIds.isNotEmpty ?? false);
                
                return const SizedBox.shrink();
              },
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => context.push(Routes.settings),
              child: const Icon(CupertinoIcons.settings),
            ),
          ],
        ),
      ),
      child: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data'));
          }
          
          // TODO: Re-implement registered classes provider
          const registeredClasses = AsyncValue<List<dynamic>>.data([]);
          
          return SingleChildScrollView(
            child: Column(
              children: [
                // Condensed profile info at top
                Container(
                color: RodaColors.surface,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    UserAvatar(
                      imageUrl: user.profilePictureUrl,
                      size: 80,
                      name: user.capoeiraName,
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
                              color: RodaColors.textSecondary,
                            ),
                          ),
                          if (user.groupName != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(CupertinoIcons.group, size: 14, color: RodaColors.secondaryLabel),
                                const SizedBox(width: 4),
                                Text(
                                  user.groupName!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: RodaColors.textSecondary,
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
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: RodaColors.primary,
                        borderRadius: BorderRadius.circular(20),
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) => CreateEditGroupModal(),
                          ).then((result) {
                            if (result == true) {
                              // Group was created successfully, refresh the list
                              ref.invalidate(userGroupsProvider);
                            }
                          });
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.add, size: 18, color: RodaColors.white),
                            SizedBox(width: 4),
                            Text('Create Group', style: TextStyle(color: RodaColors.white)),
                          ],
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
                          decoration: RodaTheme.cardDecoration,
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  CupertinoIcons.group,
                                  size: 48,
                                  color: RodaColors.textHint,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  user.role == UserRole.teacher 
                                      ? 'No groups yet. Create your first group!' 
                                      : 'You haven\'t joined any groups yet',
                                  style: TextStyle(
                                    color: RodaColors.textSecondary,
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
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: () => context.push('${Routes.group}/${group.id}'),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: RodaTheme.cardDecoration,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      // Group Avatar  
                                      GroupAvatar(
                                        imageUrl: group.headerImageUrl,
                                        size: 60,
                                        name: group.displayName,
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
                                                      color: RodaColors.secondary,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Text(
                                                      'ADMIN',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: RodaColors.white,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  )
                                                else if (isTeacher)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 8),
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: RodaColors.secondaryDark,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: const Text(
                                                      'TEACHER',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: RodaColors.white,
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
                                                  CupertinoIcons.location_solid,
                                                  size: 14,
                                                  color: RodaColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  group.city,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: RodaColors.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(
                                                  CupertinoIcons.person_2,
                                                  size: 14,
                                                  color: RodaColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${group.memberIds.length} members',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: RodaColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Arrow
                                      Icon(
                                        CupertinoIcons.chevron_forward,
                                        size: 16,
                                        color: RodaColors.textHint,
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
                      child: const Center(child: CupertinoActivityIndicator()),
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
                            CupertinoIcons.calendar,
                            size: 64,
                            color: RodaColors.systemGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No registered classes',
                            style: TextStyle(
                              fontSize: 16,
                              color: RodaColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Find and register for classes near you',
                            style: TextStyle(
                              fontSize: 14,
                              color: RodaColors.systemGrey,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CupertinoButton(
                            color: RodaColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            onPressed: () => context.push(Routes.map),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(CupertinoIcons.map, color: RodaColors.white),
                                SizedBox(width: 8),
                                Text('Browse Classes', style: TextStyle(color: RodaColors.white)),
                              ],
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
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: RodaTheme.cardDecoration,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Class ${classes.indexOf(classData) + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Class details',
                                style: TextStyle(
                                  color: RodaColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: const Center(child: CupertinoActivityIndicator()),
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
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  
  /*
  Widget _buildBottomAppBar(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isTeacher = user?.role == UserRole.teacher || 
                     (user?.teachingGroupIds.isNotEmpty ?? false);
    
    return BottomAppBar(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Home button
            InkWell(
              onTap: () => context.go(Routes.main),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.house, size: 20),
                    SizedBox(height: 2),
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
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.map, size: 20),
                    SizedBox(height: 2),
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
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.calendar_today, size: 20),
                    SizedBox(height: 2),
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
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.group, size: 20),
                    SizedBox(height: 2),
                    Text(
                      'Groups',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
            // Settings
              InkWell(
                onTap: () => context.push(Routes.editProfile),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(CupertinoIcons.settings, size: 20),
                      SizedBox(height: 2),
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
  */

}