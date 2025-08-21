import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/presentation/pages/sign_up_page.dart';
import 'package:roda/features/auth/presentation/pages/edit_profile_page.dart';
import 'package:roda/features/main/presentation/pages/main_page.dart';
import 'package:roda/features/settings/presentation/pages/settings_page.dart';
import 'package:roda/features/groups/presentation/pages/group_page.dart';
import 'package:roda/features/groups/presentation/pages/create_group_page.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/core/widgets/app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final currentUser = ref.watch(currentUserProvider);
  
  return GoRouter(
    initialLocation: Routes.main,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final hasProfile = currentUser.value != null;
      final isLoggingIn = state.matchedLocation == Routes.signUp;
      
      // Don't redirect if already on main - let them see the home tab
      // if (isLoggedIn && hasProfile && state.matchedLocation == Routes.main) {
      //   return Routes.map;
      // }
      
      // If not logged in and trying to access protected routes
      if (!isLoggedIn && !isLoggingIn && state.matchedLocation != Routes.main) {
        return Routes.signUp;
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.main,
        name: Routes.main,
        builder: (context, state) {
          final isLoggedIn = authState.value != null;
          final hasProfile = currentUser.value != null;
          
          // Show app shell for logged in users with profile
          if (isLoggedIn && hasProfile) {
            return const AppShell();
          }
          // Show main page for non-logged in or users without profile
          return const MainPage();
        },
      ),
      GoRoute(
        path: Routes.signUp,
        name: Routes.signUp,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: Routes.profile,
        name: Routes.profile,
        builder: (context, state) => const AppShell(initialIndex: 2), // Profile is now index 2
      ),
      GoRoute(
        path: Routes.editProfile,
        name: Routes.editProfile,
        builder: (context, state) => const EditProfilePage(),
      ),
      GoRoute(
        path: Routes.map,
        name: Routes.map,
        builder: (context, state) => const AppShell(initialIndex: 1), // Map is now index 1
      ),
      GoRoute(
        path: Routes.settings,
        name: Routes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: Routes.createGroup,
        name: Routes.createGroup,
        builder: (context, state) => const CreateGroupPage(),
      ),
      GoRoute(
        path: '${Routes.group}/:groupId',
        name: Routes.group,
        builder: (context, state) {
          final groupId = state.pathParameters['groupId']!;
          return AppShell(
            child: GroupPage(groupId: groupId),
          );
        },
      ),
    ],
  );
});