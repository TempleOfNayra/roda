import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/features/groups/providers/schedule_providers.dart';
import 'package:roda/features/teacher/presentation/pages/schedule_templates_page.dart';
import 'package:roda/features/groups/presentation/pages/create_edit_group_modal.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

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
  int _selectedTab = 0; // 0: Announcements, 1: Media
  
  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupByIdProvider(widget.groupId));
    final currentUser = ref.watch(currentUserProvider).value;
    
    return CupertinoPageScaffold(
      child: DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle,
        child: groupAsync.when(
          data: (group) {
            if (group == null) {
              return const Center(
                child: Text('Group not found'),
              );
            }
            
            return CustomScrollView(
            slivers: [
              // Header with back button
              CupertinoSliverNavigationBar(
                largeTitle: Text(group.name),
                backgroundColor: CupertinoColors.systemBackground.withOpacity(0.8),
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => context.pop(),
                  child: const Icon(CupertinoIcons.back),
                ),
                trailing: currentUser != null && group.createdBy == currentUser.id
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (context) => CreateEditGroupModal(
                              groupId: group.id,
                              existingGroup: group,
                            ),
                          ).then((result) {
                            if (result == true) {
                              // Group was updated successfully, refresh
                              ref.invalidate(groupByIdProvider(widget.groupId));
                            }
                          });
                        },
                        child: const Icon(CupertinoIcons.pencil),
                      )
                    : null,
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner Section
                    _buildHeaderBanner(group),
                    
                    // Group Info Section
                    _buildGroupInfo(group),
                    
                    // Teacher Section
                    _buildTeacherSection(group),
                    
                    // Description Section
                    _buildDescriptionSection(group),
                    
                    // Scheduled Classes Section
                    _buildScheduledClassesSection(group),
                    
                    // Next Roda Section
                    _buildNextRodaSection(group),
                    
                    // Followers Section
                    _buildFollowersSection(group),
                    
                    // Tabs Section
                    _buildTabsSection(group),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CupertinoActivityIndicator(),
        ),
        error: (error, _) => Center(
          child: Text('Error: $error'),
        ),
      ),
      ),
    );
  }
  
  Widget _buildHeaderBanner(CapoeiraGroup group) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5,
        image: group.headerImageUrl != null
            ? DecorationImage(
                image: NetworkImage(group.headerImageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: group.headerImageUrl == null
          ? const Center(
              child: Icon(
                CupertinoIcons.photo,
                size: 50,
                color: CupertinoColors.systemGrey,
              ),
            )
          : null,
    );
  }
  
  Widget _buildGroupInfo(CapoeiraGroup group) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          if (group.lineage != null)
            Text(
              group.lineage!.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                color: CupertinoColors.systemGrey,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            group.city.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTeacherSection(CapoeiraGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CupertinoColors.systemGrey5,
              image: group.teacherProfilePicture != null
                  ? DecorationImage(
                      image: NetworkImage(group.teacherProfilePicture!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: group.teacherProfilePicture == null
                ? const Icon(
                    CupertinoIcons.person,
                    color: CupertinoColors.systemGrey,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            group.teacherFullName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDescriptionSection(CapoeiraGroup group) {
    if (group.description == null || group.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            group.description!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScheduledClassesSection(CapoeiraGroup group) {
    final schedulesAsync = ref.watch(groupSchedulesProvider(group.id));
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _showScheduleClassModal(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    CupertinoIcons.add,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Load actual schedules from database
          schedulesAsync.when(
            data: (schedules) {
              if (schedules.isEmpty) {
                return const Text(
                  'No scheduled classes yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                );
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: schedules.map((schedule) {
                  final scheduleText = formatScheduleTime(schedule);
                  final price = schedule['price'] as num?;
                  
                  return Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          _showEditScheduleModal(context, scheduleText, schedule['id'] as String);
                        },
                        child: const Icon(
                          CupertinoIcons.pencil,
                          size: 16,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              scheduleText,
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (price != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                '\$${price.toStringAsFixed(price is int ? 0 : 2)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.systemGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
            loading: () => const CupertinoActivityIndicator(),
            error: (error, _) => const Text(
              'Failed to load schedules',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.systemRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNextRodaSection(CapoeiraGroup group) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  _showScheduleRodaModal(context);
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemOrange,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    CupertinoIcons.add,
                    color: CupertinoColors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Upcoming Roda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                '10/10/2024',
                style: TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFollowersSection(CapoeiraGroup group) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${group.memberIds.length} Followers:',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: group.memberIds.length.clamp(0, 10), // Show max 10
              itemBuilder: (context, index) {
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: CupertinoColors.systemGrey5,
                  ),
                  child: const Icon(
                    CupertinoIcons.person,
                    color: CupertinoColors.systemGrey,
                    size: 20,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTabsSection(CapoeiraGroup group) {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Tab Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _selectedTab,
            onValueChanged: (value) {
              setState(() {
                _selectedTab = value!;
              });
            },
            children: const {
              0: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('ANNOUNCEMENTS'),
              ),
              1: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('MEDIA'),
              ),
            },
          ),
        ),
        const SizedBox(height: 16),
        // Tab Content
        _selectedTab == 0 
            ? _buildAnnouncementsTab(group)
            : _buildMediaTab(group),
      ],
    );
  }
  
  Widget _buildAnnouncementsTab(CapoeiraGroup group) {
    if (group.announcements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text(
            'No announcements yet',
            style: TextStyle(
              color: CupertinoColors.systemGrey,
            ),
          ),
        ),
      );
    }
    
    return Column(
      children: group.announcements.map((announcement) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                announcement.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                announcement.content,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildMediaTab(CapoeiraGroup group) {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Center(
        child: Text(
          'No media yet',
          style: TextStyle(
            color: CupertinoColors.systemGrey,
          ),
        ),
      ),
    );
  }
  
  void _showScheduleClassModal(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => const ScheduleTemplatesPage(),
      ),
    );
  }
  
  void _showScheduleRodaModal(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => Container(
        height: 300,
        padding: const EdgeInsets.only(top: 6.0),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Schedule a Roda',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  use24hFormat: false,
                  initialDateTime: DateTime.now().add(const Duration(days: 1)),
                  onDateTimeChanged: (DateTime value) {
                    // TODO: Update the roda date
                  },
                ),
              ),
              CupertinoButton(
                child: const Text('Set Date'),
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Save the roda date
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showEditScheduleModal(BuildContext context, String schedule, String scheduleId) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text('Edit Schedule: $schedule'),
        message: const Text('What would you like to do?'),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            child: const Text('Edit Time'),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to edit schedule page with scheduleId
            },
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(context);
              // Delete this schedule
              try {
                final supabase = ref.read(supabaseClientProvider);
                await supabase
                    .from('schedules')
                    .update({'is_active': false})
                    .eq('id', scheduleId);
                // Refresh the schedules
                ref.invalidate(groupSchedulesProvider);
              } catch (e) {
                // Handle error
              }
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}