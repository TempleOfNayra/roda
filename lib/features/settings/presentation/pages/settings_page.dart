import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider).value;  // Get value directly, might be null
    final isTeacher = currentUser?.role == UserRole.teacher ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
            children: [
              // General Settings Section
              _buildSectionHeader('General'),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to edit profile
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Notifications'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to notifications settings
                },
              ),
              const Divider(),
              
              // Admin Section - Always show for development
              // if (isTeacher) ...[
                _buildSectionHeader('Admin Tools'),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, color: Colors.orange),
                  title: const Text('Clean Classes & Rodas'),
                  subtitle: const Text('Remove all schedules and class data'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCleanScheduleDialog(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Total Data Clean'),
                  subtitle: const Text('DANGER: Remove ALL data including users'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showTotalCleanDialog(context, ref),
                ),
                const Divider(),
              // ],
              
              // App Info Section
              _buildSectionHeader('About'),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('App Version'),
                subtitle: const Text('1.0.0'),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to privacy policy
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: Navigate to terms of service
                },
              ),
              const Divider(),
              
              // Sign Out - only show if user is logged in
              if (currentUser != null)
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Sign Out'),
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) {
                      context.go(Routes.main);
                    }
                  },
                ),
            ],
          ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
        ),
      ),
    );
  }
  
  Future<void> _showCleanScheduleDialog(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clean Classes & Rodas?'),
        content: const Text(
          'This will DELETE:\n'
          '• All schedule templates\n'
          '• All class instances\n'
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clean Classes & Rodas'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Show loading
    if (!context.mounted) return;
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
                Text('Cleaning schedule data...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      await _cleanScheduleData();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule data cleaned successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _showTotalCleanDialog(BuildContext context, WidgetRef ref) async {
    // First confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ TOTAL DATA CLEAN ⚠️'),
        content: const Text(
          'This will DELETE EVERYTHING:\n'
          '• All users and profiles\n'
          '• All groups\n'
          '• All schedules and classes\n'
          '• All attendance records\n'
          '• EVERYTHING!\n\n'
          'The app will be completely reset.\n'
          'This action CANNOT be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('I Understand, Continue'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Second confirmation
    if (!context.mounted) return;
    final confirmAgain = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 ARE YOU ABSOLUTELY SURE? 🚨'),
        content: const Text(
          'This will PERMANENTLY DELETE ALL DATA.\n'
          'You will be signed out and all users will need to sign up again.\n\n'
          'Type "DELETE ALL" to confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE ALL DATA'),
          ),
        ],
      ),
    );
    
    if (confirmAgain != true) return;
    
    // Show loading
    if (!context.mounted) return;
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
                Text('Deleting all data...'),
              ],
            ),
          ),
        ),
      ),
    );
    
    try {
      await _totalDataClean();
      
      // Sign out after cleaning
      await ref.read(authServiceProvider).signOut();
      
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        context.go(Routes.main);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data has been deleted. App reset complete.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // Clean only schedule-related data
  Future<void> _cleanScheduleData() async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    
    // Delete all schedule templates
    final templates = await db.collection('schedule_templates').get();
    for (final doc in templates.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete all class instances
    final instances = await db.collection('class_instances').get();
    for (final doc in instances.docs) {
      batch.delete(doc.reference);
    }
    
    // Delete all classes (old model)
    final classes = await db.collection('classes').get();
    for (final doc in classes.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
    print('✅ Schedule data cleaned successfully');
  }
  
  // Clean EVERYTHING
  Future<void> _totalDataClean() async {
    final db = FirebaseFirestore.instance;
    
    // List of all collections to delete
    final collections = [
      'users',
      'groups',
      'capoeira_groups',
      'events',
      'schedule_templates',
      'class_instances',
      'classes',
    ];
    
    for (final collection in collections) {
      final batch = db.batch();
      final docs = await db.collection(collection).get();
      
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      print('✅ Deleted all documents from $collection');
    }
    
    print('✅ Total data clean complete');
  }
}