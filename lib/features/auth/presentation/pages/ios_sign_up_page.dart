import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, DropdownMenuItem, DropdownButtonFormField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/core/theme/ios_theme.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/auth/presentation/widgets/auth_button.dart';
import 'package:roda/core/widgets/birthday_picker.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/core/utils/logger.dart';

class IOSSignUpPage extends ConsumerStatefulWidget {
  const IOSSignUpPage({super.key});

  @override
  ConsumerState<IOSSignUpPage> createState() => _IOSSignUpPageState();
}

class _IOSSignUpPageState extends ConsumerState<IOSSignUpPage> {
  final _formKey = GlobalKey<FormState>();
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
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Sign Up'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text('Back'),
          onPressed: () async {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              context.go(Routes.main);
            }
          },
        ),
      ),
      child: SafeArea(
        child: authState.when(
          data: (user) {
            if (user == null) {
              return _buildSignInOptions();
            }
            return _buildSignUpForm();
          },
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚠', 
                  style: TextStyle(fontSize: 48, color: CupertinoColors.systemRed)
                ),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                CupertinoButton(
                  child: const Text('Retry'),
                  onPressed: () {
                    ref.invalidate(authStateProvider);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInOptions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Welcome to RODA',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.41,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to get started',
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          
          // OAuth Sign In Buttons
          _buildSignInButton(
            label: 'Continue with Apple',
            onPressed: _signInWithApple,
            isPrimary: true,
          ),
          const SizedBox(height: 16),
          _buildSignInButton(
            label: 'Continue with Google',
            onPressed: _signInWithGoogle,
            isPrimary: false,
          ),
          
          if (const bool.fromEnvironment('dart.vm.product') == false) ...[
            const SizedBox(height: 32),
            CupertinoButton(
              color: CupertinoColors.systemOrange,
              child: const Text('DEBUG: Test User', style: TextStyle(color: CupertinoColors.white)),
              onPressed: _debugSignInAsFirstUser,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignInButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return SizedBox(
      height: 50,
      child: CupertinoButton(
        color: isPrimary ? CupertinoColors.black : CupertinoColors.white,
        borderRadius: BorderRadius.circular(12),
        onPressed: _isSigningIn ? null : onPressed,
        child: _isSigningIn
          ? CupertinoActivityIndicator(
              color: isPrimary ? CupertinoColors.white : CupertinoColors.black,
            )
          : Text(label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isPrimary ? CupertinoColors.white : CupertinoColors.black,
              ),
            ),
      ),
    );
  }

  Widget _buildSignUpForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Complete Your Profile',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            
            // Full Name
            _buildTextField(
              controller: _fullNameController,
              placeholder: 'Full Name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Capoeira Name
            _buildTextField(
              controller: _capoeiraNameController,
              placeholder: 'Capoeira Name',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your Capoeira name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Birthday
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
            
            // Role Selection
            CupertinoSlidingSegmentedControl<UserRole>(
              groupValue: _selectedRole,
              children: const {
                UserRole.student: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Student'),
                ),
                UserRole.teacher: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Teacher'),
                ),
              },
              onValueChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              },
            ),
            
            if (_selectedRole == UserRole.teacher) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Group Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _groupNameController,
                      placeholder: 'Group Name (e.g., Filhos De Dunga)',
                      validator: (value) {
                        if (_selectedRole == UserRole.teacher && 
                            (value == null || value.isEmpty)) {
                          return 'Please enter your group name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _groupAffiliationController,
                      placeholder: 'Affiliation/Branch (optional)',
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _groupCityController,
                      placeholder: 'City',
                      validator: (value) {
                        if (_selectedRole == UserRole.teacher && 
                            (value == null || value.isEmpty)) {
                          return 'Please enter your city';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _groupVenmoController,
                      placeholder: 'Venmo Handle (optional)',
                      prefix: '@',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Note: You\'ll set up your class schedule after signing up.',
                      style: TextStyle(
                        fontSize: 14,
                        color: CupertinoColors.secondaryLabel,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: _groupNameController,
                placeholder: 'Group Name (optional)',
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _teacherNameController,
                placeholder: 'Teacher Name (optional)',
              ),
            ],
            
            const SizedBox(height: 32),
            CupertinoButton.filled(
              onPressed: _isLoading ? null : _submitForm,
              child: _isLoading
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : const Text(
                    'Complete Sign Up',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return CupertinoTextFormFieldRow(
      controller: controller,
      placeholder: placeholder,
      prefix: prefix != null ? Text(prefix, style: const TextStyle(color: CupertinoColors.systemGrey)) : null,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(10),
      ),
      validator: validator,
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();
      
      if (user != null && mounted) {
        context.go(Routes.profile);
      } else if (mounted) {
        setState(() => _isSigningIn = false);
      }
    } catch (e) {
      Logger.debug('OAuth sign in error: $e');
      if (mounted) {
        _showErrorDialog('Sign in failed: ${e.toString().replaceAll('Exception: ', '')}');
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
        context.go(Routes.profile);
      } else if (mounted) {
        setState(() => _isSigningIn = false);
      }
    } catch (e) {
      Logger.debug('OAuth sign in error: $e');
      if (mounted) {
        _showErrorDialog('Sign in failed: ${e.toString().replaceAll('Exception: ', '')}');
        setState(() => _isSigningIn = false);
      }
    }
  }

  Future<void> _debugSignInAsFirstUser() async {
    setState(() {
      _fullNameController.text = 'Test User';
      _capoeiraNameController.text = 'Mestre Test';
      _selectedRole = UserRole.teacher;
      _groupNameController.text = 'Test Academy';
      _groupCityController.text = 'Test City';
      _dateOfBirth = DateTime(1990, 1, 1);
    });
    
    _showSuccessDialog('Form pre-filled with test data. Review and submit.');
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dateOfBirth == null) {
      _showErrorDialog('Please select your date of birth');
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final groupService = ref.read(supabaseGroupServiceProvider);
      
      // Check for existing group (teachers only)
      if (_selectedRole == UserRole.teacher && 
          _groupNameController.text.isNotEmpty) {
        
        final existingGroup = await groupService.findExistingGroup(
          _groupNameController.text,
          _groupAffiliationController.text.isNotEmpty 
              ? _groupAffiliationController.text 
              : null,
        );
        
        if (existingGroup != null && mounted) {
          final shouldJoin = await _showJoinGroupDialog(existingGroup);
          
          if (shouldJoin == true) {
            // Join existing group
            await _createUserAndJoinGroup(true);
            return;
          } else if (shouldJoin == false) {
            setState(() => _isLoading = false);
            return;
          }
        }
      }
      
      // Create new user/group
      await _createUserAndJoinGroup(false);
      
    } catch (e) {
      Logger.debug('Sign up error: $e');
      if (mounted) {
        _showErrorDialog('Sign up failed: ${e.toString().replaceAll('Exception: ', '')}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createUserAndJoinGroup(bool joinExisting) async {
    final authService = ref.read(authServiceProvider);
    
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
      joinExistingGroup: joinExisting,
    );
    
    // Force refresh and navigate
    ref.invalidate(currentUserProvider);
    
    if (mounted) {
      context.go(Routes.profile);
    }
  }

  Future<bool?> _showJoinGroupDialog(dynamic existingGroup) async {
    return showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: const Text('Group Already Exists'),
          content: Text(
            'A group named "${existingGroup.displayName}" already exists. '
            'Would you like to join as a teacher?'
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Join Group'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
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