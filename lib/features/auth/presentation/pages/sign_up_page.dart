import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/auth/presentation/widgets/auth_button.dart';
import 'package:roda/core/widgets/birthday_picker.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
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
  void initState() {
    super.initState();
    // Remove auth state checking - it's overthinking the flow
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Sign out first to prevent redirect loop
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              context.go(Routes.main);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: authState.when(
            data: (user) {
              if (user == null) {
                return _buildSignInOptions();
              }
              return _buildSignUpForm();
            },
            loading: () => const Center(child: CircularProgressIndicator()),
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
            color: Colors.grey,
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
        const Divider(),
        const SizedBox(height: 16),
        // DEBUG: Quick sign in as first user
        ElevatedButton.icon(
          onPressed: _debugSignInAsFirstUser,
          icon: const Icon(Icons.bug_report),
          label: const Text('DEBUG: Sign in as First User'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm() {
    return Form(
      key: _formKey,
      child: Column(
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
          TextFormField(
            controller: _fullNameController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your full name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _capoeiraNameController,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Capoeira Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your Capoeira name';
              }
              return null;
            },
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
          DropdownButtonFormField<UserRole>(
            initialValue: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: UserRole.values.map((role) {
              return DropdownMenuItem(
                value: role,
                child: Text(role.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedRole = value!;
              });
            },
          ),
          const SizedBox(height: 16),
          if (_selectedRole == UserRole.teacher) ...[
            const Divider(height: 32),
            const Text(
              'Complete Your Group Info',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupNameController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Group Name (e.g., Filhos De Dunga)',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_selectedRole == UserRole.teacher && 
                    (value == null || value.isEmpty)) {
                  return 'Please enter your group name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupAffiliationController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Affiliation/Branch (e.g., Capoeira Angola Center of Mestre João Grande)',
                border: OutlineInputBorder(),
                hintText: 'Optional',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupCityController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (_selectedRole == UserRole.teacher && 
                    (value == null || value.isEmpty)) {
                  return 'Please enter your city';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCountry,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'US',
                  child: Text('United States'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCountry = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupVenmoController,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Venmo Handle (for payments)',
                border: OutlineInputBorder(),
                hintText: 'your-venmo-handle',
                prefixText: '@',
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // Remove @ if user included it (since we have prefixText)
                  if (value.startsWith('@')) {
                    _groupVenmoController.text = value.substring(1);
                  }
                }
                return null; // Optional field
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: You\'ll set up your class schedule after signing up.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ] else ...[
            TextFormField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _teacherNameController,
              decoration: const InputDecoration(
                labelText: 'Teacher Name (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text(
                    'Complete Sign Up',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ],
      ),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in anonymously. Form pre-filled - review and submit.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Debug sign in failed: $e\nEnable Anonymous auth in Firebase Console')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
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
            } else if (existingGroup.teacherName != null && existingGroup.teacherName!.isNotEmpty) {
              // Fall back to teacherName stored in the group
              creatorName = existingGroup.teacherName!;
            }
          } catch (e) {
            // If we can't get creator info, use default
            print('Could not get creator info: $e');
          }
          
          // Show dialog asking if they want to join the existing group
          if (mounted) {
            final shouldJoin = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Group Already Exists'),
                  content: Text(
                    'There is already a group named "${existingGroup.displayName}" created by $creatorName. '
                    'Do you want to be added to that group as a teacher?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('No, Cancel'),
                    ),
                    ElevatedButton(
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
      
      if (mounted) {
        // Always go to profile after sign up
        context.go(Routes.profile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign up failed: $e')),
        );
      }
    }
    
    setState(() => _isLoading = false);
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