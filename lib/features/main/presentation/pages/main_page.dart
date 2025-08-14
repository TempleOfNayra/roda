import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/features/main/cleanup_schedule_data.dart';

class MainPage extends ConsumerWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Center(
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
        if (isTeacher) ...[
          ElevatedButton.icon(
            onPressed: () => _cleanDatabase(context, ref),
            icon: const Icon(Icons.cleaning_services),
            label: const Text('Clean Database'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextButton(
          onPressed: () async {
            await ref.read(authServiceProvider).signOut();
          },
          child: const Text('Sign Out'),
        ),
      ],
    );
  }
  
  Future<void> _cleanDatabase(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Schedule Data?'),
        content: const Text(
          'This will DELETE:\n'
          '• All schedule templates\n'
          '• All class instances\n'
          '• All old classes\n'
          '• All attendance records\n\n'
          'This will PRESERVE:\n'
          '• User accounts\n'
          '• Groups\n'
          '• User profiles\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Second confirmation
    final confirmAgain = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you ABSOLUTELY sure?'),
        content: const Text(
          'This will permanently delete ALL data. Type "DELETE" to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('I understand, DELETE ALL'),
          ),
        ],
      ),
    );
    
    if (confirmAgain != true) return;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Cleaning database...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      // Use the safer cleanup function that preserves users and groups
      await cleanupScheduleData();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule data cleaned successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // DO NOT sign out - user profile still exists
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cleaning database: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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