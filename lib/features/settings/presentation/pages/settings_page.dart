import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:roda/core/theme/roda_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      backgroundColor: RodaColors.background,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: RodaColors.surface,
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              
              // Account section
              _buildSection(
                title: 'Account',
                items: [
                  _buildSettingsItem(
                    icon: CupertinoIcons.person,
                    title: 'Edit Profile',
                    onTap: () {
                      // TODO: Navigate to edit profile
                    },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.bell,
                    title: 'Notifications',
                    onTap: () {
                      // TODO: Navigate to notifications settings
                    },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.lock,
                    title: 'Privacy',
                    onTap: () {
                      // TODO: Navigate to privacy settings
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // Support section
              _buildSection(
                title: 'Support',
                items: [
                  _buildSettingsItem(
                    icon: CupertinoIcons.question_circle,
                    title: 'Help & FAQ',
                    onTap: () {
                      // TODO: Navigate to help
                    },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.mail,
                    title: 'Contact Us',
                    onTap: () {
                      // TODO: Open contact form or email
                    },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.doc_text,
                    title: 'Terms of Service',
                    onTap: () {
                      // TODO: Navigate to terms
                    },
                  ),
                  _buildSettingsItem(
                    icon: CupertinoIcons.shield,
                    title: 'Privacy Policy',
                    onTap: () {
                      // TODO: Navigate to privacy policy
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 30),
              
              // App Info section
              _buildSection(
                title: 'App Info',
                items: [
                  _buildSettingsItem(
                    icon: CupertinoIcons.info,
                    title: 'About',
                    subtitle: 'Version 1.0.0',
                    onTap: () {
                      // TODO: Show about dialog
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // Sign out button
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                child: CupertinoButton(
                  color: RodaColors.error,
                  borderRadius: BorderRadius.circular(12),
                  onPressed: () {
                    _showSignOutDialog(context);
                  },
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: RodaColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: RodaTheme.cardDecoration,
          child: Column(
            children: items,
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: RodaColors.primary.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: RodaColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: RodaColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              size: 16,
              color: RodaColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSignOutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Implement sign out logic
            },
          ),
        ],
      ),
    );
  }
}