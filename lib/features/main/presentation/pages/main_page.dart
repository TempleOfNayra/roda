import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/core/models/user_model.dart';

class MainPage extends ConsumerWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Settings icon in top right
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push(Routes.settings),
              ),
            ),
            // Main content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'RODA',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                const SizedBox(height: 8),
                const Text(
                  'Capoeira Class & Roda Tracker',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 48),
                authState.when(
                  data: (user) {
                    if (user == null) {
                      return _buildSignedOutButtons(context);
                    } else {
                      return currentUser.when(
                        data: (userData) {
                          if (userData == null) {
                            // User authenticated but no profile yet
                            return _buildSignUpButton(context);
                          }
                          return _buildSignedInButtons(context, ref, userData);
                        },
                        loading: () => const CircularProgressIndicator(),
                        error: (error, _) => Text('Error: $error'),
                      );
                    }
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (error, _) => Text('Error: $error'),
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

  Widget _buildSignedOutButtons(BuildContext context) {
    return Column(
      children: [
        _buildMainButton(
          context: context,
          icon: Icons.login,
          label: 'Sign Up / Sign In',
          onPressed: () => context.push(Routes.signUp),
        ),
        const SizedBox(height: 16),
        _buildMainButton(
          context: context,
          icon: Icons.map,
          label: 'Browse Classes',
          onPressed: () => context.push(Routes.map),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(BuildContext context) {
    return _buildMainButton(
      context: context,
      icon: Icons.person_add,
      label: 'Complete Profile',
      onPressed: () => context.push(Routes.signUp),
    );
  }

  Widget _buildSignedInButtons(BuildContext context, WidgetRef ref, dynamic userData) {
    final isTeacher = userData.role == UserRole.teacher;
    
    return Column(
      children: [
        Text(
          'Welcome, ${userData.capoeiraName}!',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 32),
        _buildMainButton(
          context: context,
          icon: Icons.person,
          label: 'My Profile',
          onPressed: () => context.push(Routes.profile),
        ),
        const SizedBox(height: 16),
        _buildMainButton(
          context: context,
          icon: Icons.map,
          label: 'Class Map',
          onPressed: () => context.push(Routes.map),
        ),
        if (isTeacher) ...[
          const SizedBox(height: 16),
          _buildMainButton(
            context: context,
            icon: Icons.dashboard,
            label: 'Teacher Dashboard',
            onPressed: () => context.push(Routes.teacherDashboard),
          ),
        ],
        const SizedBox(height: 32),
        TextButton(
          onPressed: () async {
            await ref.read(authServiceProvider).signOut();
          },
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
  
  Widget _buildMainButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16),
        ),
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}