import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/presentation/pages/sign_up_page.dart';
import 'package:roda/features/auth/presentation/pages/profile_page.dart';
import 'package:roda/features/main/presentation/pages/main_page.dart';
import 'package:roda/features/teacher/presentation/pages/teacher_dashboard_page.dart';
import 'package:roda/features/classes/presentation/pages/clean_map_page.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  
  return GoRouter(
    initialLocation: Routes.main,
    redirect: (context, state) {
      final isLoggedIn = authState.value != null;
      final isLoggingIn = state.matchedLocation == Routes.signUp;
      
      if (!isLoggedIn && !isLoggingIn && state.matchedLocation != Routes.main) {
        return Routes.signUp;
      }
      
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.main,
        name: Routes.main,
        builder: (context, state) => const MainPage(),
      ),
      GoRoute(
        path: Routes.signUp,
        name: Routes.signUp,
        builder: (context, state) => const SignUpPage(),
      ),
      GoRoute(
        path: Routes.profile,
        name: Routes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: Routes.teacherDashboard,
        name: Routes.teacherDashboard,
        builder: (context, state) => const TeacherDashboardPage(),
      ),
      GoRoute(
        path: Routes.map,
        name: Routes.map,
        builder: (context, state) => const CleanMapPage(),
      ),
    ],
  );
});