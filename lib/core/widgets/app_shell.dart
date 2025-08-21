import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/features/main/presentation/pages/main_page.dart';
import 'package:roda/features/classes/presentation/pages/clean_map_page.dart';
import 'package:roda/features/auth/presentation/pages/profile_page.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/core/widgets/user_avatar.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget? child;
  final int? initialIndex;
  
  const AppShell({
    super.key, 
    this.child,
    this.initialIndex,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _selectedIndex;
  
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
  }

  final List<Widget> _pages = const [
    MainPage(),     // Home
    CleanMapPage(), // Map
    ProfilePage(),  // Profile
  ];

  @override
  Widget build(BuildContext context) {
    // If a child is provided (like GroupPage), show it with the tab bar
    if (widget.child != null) {
      return CupertinoPageScaffold(
        child: Column(
          children: [
            Expanded(child: widget.child!),
            Container(
              decoration: BoxDecoration(
                color: RodaColors.surface.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: RodaColors.divider.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: CupertinoTabBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) {
                    // Don't update state when navigating from child pages
                    // Just navigate directly
                    if (index == 0) {
                      // Navigate to home
                      context.go(Routes.main);
                    } else if (index == 1) {
                      // Navigate to map
                      context.go(Routes.map);
                    } else if (index == 2) {
                      // Navigate to profile  
                      context.go(Routes.profile);
                    }
                  },
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.home),
                      label: 'Home',
                    ),
                    const BottomNavigationBarItem(
                      icon: Icon(CupertinoIcons.map),
                      label: 'Map',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildProfileIcon(ref),
                      label: 'Profile',
                    ),
                  ],
                  activeColor: RodaColors.primary,
                  inactiveColor: RodaColors.textHint,
                  backgroundColor: RodaColors.transparent,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Default tab scaffold behavior - simplified without CupertinoTabView
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: _buildProfileIcon(ref),
            label: 'Profile',
          ),
        ],
        activeColor: RodaColors.primary,
        inactiveColor: RodaColors.textHint,
        backgroundColor: RodaColors.surface.withValues(alpha: 0.95),
      ),
      tabBuilder: (context, index) {
        // Return the page directly without CupertinoTabView wrapper
        return _pages[index];
      },
    );
  }
  
  Widget _buildProfileIcon(WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;
    
    if (currentUser != null) {
      return UserAvatar(
        imageUrl: currentUser.profilePictureUrl,
        size: 24,
        name: currentUser.fullName,
      );
    }
    
    return const Icon(CupertinoIcons.person_circle);
  }
}