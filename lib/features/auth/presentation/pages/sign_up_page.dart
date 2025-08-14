import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/core/routing/routes.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/features/auth/presentation/widgets/auth_button.dart';
import 'package:intl/intl.dart';

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
    _checkAuthState();
  }

  void _checkAuthState() {
    final authState = ref.read(authStateProvider);
    authState.whenData((user) {
      if (user != null && !_isSigningIn) {
        // User is authenticated, check if they have a profile
        final currentUser = ref.read(currentUserProvider);
        currentUser.whenData((userData) {
          if (userData != null) {
            // User has a profile, redirect to main
            context.go(Routes.main);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
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
          const SizedBox(height: 16),
          // Add sign out option if stuck
          ElevatedButton.icon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                context.go(Routes.main);
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('SIGN OUT - START OVER'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
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
          InkWell(
            onTap: _selectDateOfBirth,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _dateOfBirth != null
                    ? DateFormat('MMM dd, yyyy').format(_dateOfBirth!)
                    : 'Select date',
                style: TextStyle(
                  color: _dateOfBirth != null ? null : Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserRole>(
            value: _selectedRole,
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
              value: _selectedCountry,
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
                hintText: '@your-venmo-handle',
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

  Future<void> _selectDateOfBirth() async {
    // Start with year selection for birthdays
    final currentYear = DateTime.now().year;
    final initialYear = currentYear - 25; // Default to 25 years ago
    
    // First show a dialog to select the year
    final selectedYear = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Birth Year'),
        content: SizedBox(
          width: double.minPositive,
          height: 300,
          child: YearPicker(
            firstDate: DateTime(1900),
            lastDate: DateTime.now(),
            selectedDate: DateTime(initialYear),
            onChanged: (DateTime dateTime) {
              Navigator.pop(context, dateTime.year);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (selectedYear != null) {
      // Then show date picker with the selected year
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime(selectedYear, 6, 15), // Mid-year default
        firstDate: DateTime(selectedYear, 1, 1),
        lastDate: DateTime(selectedYear, 12, 31),
        initialDatePickerMode: DatePickerMode.day,
      );
      
      if (picked != null) {
        setState(() {
          _dateOfBirth = picked;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSigningIn = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();
      
      if (user != null && mounted) {
        // User exists, go to main
        context.go(Routes.main);
      } else {
        // User is null, they need to complete sign-up
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
        // User exists, go to main
        context.go(Routes.main);
      } else {
        // User is null, they need to complete sign-up
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
      await FirebaseAuth.instance.signInAnonymously();
      
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
        if (_selectedRole == UserRole.teacher) {
          // TODO: Navigate to teacher setup flow
          context.go(Routes.profile);
        } else {
          context.go(Routes.main);
        }
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