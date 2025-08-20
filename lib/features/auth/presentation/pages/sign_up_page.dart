import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/auth/presentation/widgets/auth_button.dart';
import 'package:roda/core/widgets/birthday_picker.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/core/utils/logger.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _fullNameController = TextEditingController();
  final _capoeiraNameController = TextEditingController();
  final _groupNameController = TextEditingController();
  final _groupAffiliationController = TextEditingController();
  final _groupCityController = TextEditingController();
  final _groupVenmoController = TextEditingController();
  final _teacherNameController = TextEditingController();
  
  DateTime? _dateOfBirth;
  UserRole _selectedRole = UserRole.student;
  String _selectedCountry = 'US';
  bool _isLoading = false;
  bool _isSigningIn = false;

  @override
  void initState() {
    super.initState();
    // Remove auth state checking - it's overthinking the flow
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Sign Up'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.back),
          onPressed: () async {
            // Sign out first to prevent redirect loop
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              context.go(Routes.main);
            }
          },
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: authState.when(
            data: (user) {
              if (user == null) {
                return _buildSignInOptions();
              }
              return _buildSignUpForm();
            },
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Welcome to RODA',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text(
          'Sign in to get started',
          style: TextStyle(
            fontSize: 16,
            color: CupertinoColors.secondaryLabel,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),
        AuthButton(
          text: 'Continue with Google',
          icon: Icons.g_mobiledata,
          onPressed: _signInWithGoogle,
          isLoading: _isSigningIn,
        ),
        const SizedBox(height: 16),
        AuthButton(
          text: 'Continue with Apple',
          icon: Icons.apple,
          onPressed: _signInWithApple,
          isLoading: _isSigningIn,
        ),
        const SizedBox(height: 32),
        Container(
          height: 1,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: CupertinoColors.separator,
                width: 0.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // DEBUG: Quick sign in as first user
        CupertinoButton.filled(
          onPressed: _debugSignInAsFirstUser,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bug_report, color: CupertinoColors.white),
              const SizedBox(width: 8),
              const Text('DEBUG: Sign in as First User'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Complete Your Profile',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Full Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _fullNameController,
                autocorrect: false,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Capoeira Name',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoTextField(
                controller: _capoeiraNameController,
                autocorrect: false,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          BirthdayPicker(
            initialDate: _dateOfBirth,
            onDateSelected: (date) {
              setState(() {
                _dateOfBirth = date;
              });
            },
            labelText: 'Date of Birth',
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Role',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => _showRolePicker(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedRole.name.toUpperCase(),
                        style: const TextStyle(color: CupertinoColors.label),
                      ),
                      const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedRole == UserRole.teacher) ...[
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator,
                    width: 0.0,
                  ),
                ),
              ),
            ),
            const Text(
              'Complete Your Group Info',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Group Name (e.g., Filhos De Dunga)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _groupNameController,
                  autocorrect: false,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Affiliation/Branch (e.g., Capoeira Angola Center of Mestre João Grande)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _groupAffiliationController,
                  autocorrect: false,
                  padding: const EdgeInsets.all(16),
                  placeholder: 'Optional',
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'City',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _groupCityController,
                  autocorrect: false,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Country',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _showCountryPicker(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: CupertinoColors.systemGrey4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCountry == 'US' ? 'United States' : _selectedCountry,
                          style: const TextStyle(color: CupertinoColors.label),
                        ),
                        const Icon(CupertinoIcons.chevron_down, color: CupertinoColors.systemGrey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Venmo Handle (for payments)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _groupVenmoController,
                  autocorrect: false,
                  padding: const EdgeInsets.all(16),
                  placeholder: 'your-venmo-handle',
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text('@', style: TextStyle(color: CupertinoColors.label)),
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: You\'ll set up your class schedule after signing up.',
              style: TextStyle(
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ] else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Group Name',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _groupNameController,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Teacher Name (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _teacherNameController,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.systemGrey4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          CupertinoButton.filled(
            onPressed: _isLoading ? null : _submitForm,
            child: _isLoading
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : const Text(
                    'Complete Sign Up',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ],
    );
  }


  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();
      
      if (user != null && mounted) {
        // User exists, go to profile
        context.go(Routes.profile);
      } else {
        // User is null, they need to complete profile
        // The auth state will trigger a rebuild showing the form
        if (mounted) {
          setState(() => _isSigningIn = false);
        }
      }
    } catch (e, stackTrace) {
      Logger.debug('OAuth sign in error: $e');
      Logger.debug('Stack trace: $stackTrace');
      if (mounted) {
        _showCupertinoDialog(context, 'Error', 'Sign in failed: $e');
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isSigningIn = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithApple();
      
      if (user != null && mounted) {
        // User exists, go to profile
        context.go(Routes.profile);
      } else {
        // User is null, they need to complete profile
        // The auth state will trigger a rebuild showing the form
        if (mounted) {
          setState(() => _isSigningIn = false);
        }
      }
    } catch (e, stackTrace) {
      Logger.debug('OAuth sign in error: $e');
      Logger.debug('Stack trace: $stackTrace');
      if (mounted) {
        _showCupertinoDialog(context, 'Error', 'Sign in failed: $e');
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _debugSignInAsFirstUser() async {
    // Sign in anonymously first
    try {
      // Skip anonymous sign in for Supabase
      // await Supabase.instance.client.auth.signInAnonymously();
      
      // Pre-fill the form with test data
      setState(() {
        _fullNameController.text = 'Test User';
        _capoeiraNameController.text = 'Mestre Test';
        _selectedRole = UserRole.teacher;
        _groupNameController.text = 'Test Academy';
        _dateOfBirth = DateTime(1990, 1, 1);
      });
      
      if (mounted) {
        _showCupertinoDialog(context, 'Debug Sign In', 'Signed in anonymously. Form pre-filled - review and submit.');
      }
    } catch (e) {
      if (mounted) {
        _showCupertinoDialog(context, 'Error', 'Debug sign in failed: $e\nEnable Anonymous auth in Firebase Console');
      }
    }
  }

  Future<void> _submitForm() async {
    // Manual validation since we're using CupertinoTextFields
    if (_fullNameController.text.isEmpty) {
      _showCupertinoDialog(context, 'Missing Information', 'Please enter your full name');
      return;
    }
    
    if (_capoeiraNameController.text.isEmpty) {
      _showCupertinoDialog(context, 'Missing Information', 'Please enter your Capoeira name');
      return;
    }
    
    if (_selectedRole == UserRole.teacher) {
      if (_groupNameController.text.isEmpty) {
        _showCupertinoDialog(context, 'Missing Information', 'Please enter your group name');
        return;
      }
      if (_groupCityController.text.isEmpty) {
        _showCupertinoDialog(context, 'Missing Information', 'Please enter your city');
        return;
      }
    }
    
    if (_dateOfBirth == null) {
      _showCupertinoDialog(context, 'Missing Information', 'Please select your date of birth');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final groupService = ref.read(supabaseGroupServiceProvider);
      
      // Check if a group with this name already exists (only for teachers)
      if (_selectedRole == UserRole.teacher && 
          _groupNameController.text.isNotEmpty) {
        
        final existingGroup = await groupService.findExistingGroup(
          _groupNameController.text,
          _groupAffiliationController.text.isNotEmpty 
              ? _groupAffiliationController.text 
              : null,
        );
        
        if (existingGroup != null) {
          // Get creator info
          String creatorName = 'another teacher';
          try {
            final creatorInfo = await groupService.getGroupCreatorInfo(_groupNameController.text, null);
            if (creatorInfo != null && creatorInfo['name'] != null) {
              creatorName = creatorInfo['name']!;
            } else if (existingGroup.teacherFullName.isNotEmpty) {
              // Fall back to teacherFullName stored in the group
              creatorName = existingGroup.teacherFullName;
            }
          } catch (e) {
            // If we can't get creator info, use default
            Logger.debug('Could not get creator info: $e');
          }
          
          // Show dialog asking if they want to join the existing group
          if (mounted) {
            final shouldJoin = await showCupertinoDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return CupertinoAlertDialog(
                  title: const Text('Group Already Exists'),
                  content: Text(
                    'There is already a group named "${existingGroup.displayName}" created by $creatorName. '
                    'Do you want to be added to that group as a teacher?'
                  ),
                  actions: [
                    CupertinoDialogAction(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No, Cancel'),
                    ),
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Yes, Join Group'),
                    ),
                  ],
                );
              },
            );
            
            if (shouldJoin == true) {
              // Create user and join existing group
              await authService.createUser(
                fullName: _fullNameController.text,
                capoeiraName: _capoeiraNameController.text,
                dateOfBirth: _dateOfBirth!,
                role: _selectedRole,
                groupName: _groupNameController.text,
                groupAffiliation: _groupAffiliationController.text.isNotEmpty
                    ? _groupAffiliationController.text
                    : null,
                groupCity: _groupCityController.text.isNotEmpty
                    ? _groupCityController.text
                    : null,
                groupCountry: _selectedCountry,
                groupVenmo: _groupVenmoController.text.isNotEmpty
                    ? _groupVenmoController.text
                    : null,
                teacherName: _teacherNameController.text.isNotEmpty
                    ? _teacherNameController.text
                    : null,
                joinExistingGroup: true,
              );
              
              // Force a refresh of the current user provider
              ref.invalidate(currentUserProvider);
              
              if (mounted) {
                context.go(Routes.profile);
              }
              setState(() => _isLoading = false);
              return;
            } else {
              // User chose not to join, just return
              setState(() => _isLoading = false);
              return;
            }
          }
        }
      }
      
      // No existing group or not a teacher, proceed with normal creation
      await authService.createUser(
        fullName: _fullNameController.text,
        capoeiraName: _capoeiraNameController.text,
        dateOfBirth: _dateOfBirth!,
        role: _selectedRole,
        groupName: _groupNameController.text.isNotEmpty 
            ? _groupNameController.text 
            : null,
        groupAffiliation: _groupAffiliationController.text.isNotEmpty
            ? _groupAffiliationController.text
            : null,
        groupCity: _groupCityController.text.isNotEmpty
            ? _groupCityController.text
            : null,
        groupCountry: _selectedCountry,
        groupVenmo: _groupVenmoController.text.isNotEmpty
            ? _groupVenmoController.text
            : null,
        teacherName: _teacherNameController.text.isNotEmpty
            ? _teacherNameController.text
            : null,
      );
      
      // Force a refresh of the current user provider
      ref.invalidate(currentUserProvider);
      
      if (mounted) {
        // Always go to profile after sign up
        context.go(Routes.profile);
      }
    } catch (e, stackTrace) {
      Logger.debug('Sign up error: $e');
      Logger.debug('Stack trace: $stackTrace');
      if (mounted) {
        _showCupertinoDialog(context, 'Error', 'Sign up failed: $e');
      }
    }
    
    setState(() => _isLoading = false);
  }

  void _showCupertinoDialog(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showRolePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: CupertinoPicker(
              magnification: 1.22,
              squeeze: 1.2,
              useMagnifier: true,
              itemExtent: 32.0,
              scrollController: FixedExtentScrollController(
                initialItem: UserRole.values.indexOf(_selectedRole),
              ),
              onSelectedItemChanged: (int selectedItem) {
                setState(() {
                  _selectedRole = UserRole.values[selectedItem];
                });
              },
              children: UserRole.values.map((role) {
                return Center(
                  child: Text(
                    role.name.toUpperCase(),
                    style: const TextStyle(fontSize: 18.0),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showCountryPicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 200,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: CupertinoColors.systemBackground.resolveFrom(context),
          child: SafeArea(
            top: false,
            child: CupertinoPicker(
              magnification: 1.22,
              squeeze: 1.2,
              useMagnifier: true,
              itemExtent: 32.0,
              scrollController: FixedExtentScrollController(
                initialItem: _selectedCountry == 'US' ? 0 : 0,
              ),
              onSelectedItemChanged: (int selectedItem) {
                setState(() {
                  _selectedCountry = 'US'; // Only US for now
                });
              },
              children: const [
                Center(
                  child: Text(
                    'United States',
                    style: TextStyle(fontSize: 18.0),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _capoeiraNameController.dispose();
    _groupNameController.dispose();
    _groupAffiliationController.dispose();
    _groupCityController.dispose();
    _groupVenmoController.dispose();
    _teacherNameController.dispose();
    super.dispose();
  }
}