import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:roda/core/config/supabase_config.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:roda/core/models/user_model.dart';
import 'package:roda/features/auth/providers/auth_provider.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/services/r2_storage_service.dart';
import 'package:roda/core/widgets/birthday_picker.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _capoeiraNameController;
  late TextEditingController _groupNameController;
  late TextEditingController _venmoController;
  DateTime? _dateOfBirth;
  bool _isLoading = false;
  bool _isInitialized = false;
  CapoeiraGroup? _userGroup;
  XFile? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _capoeiraNameController = TextEditingController();
    _groupNameController = TextEditingController();
    _venmoController = TextEditingController();
  }

  void _initializeControllers(UserModel user) {
    if (!_isInitialized) {
      _fullNameController.text = user.fullName;
      _capoeiraNameController.text = user.capoeiraName;
      _groupNameController.text = user.groupName ?? '';
      _dateOfBirth = user.dateOfBirth;
      _isInitialized = true;
      
      // Load group data if user has teaching groups
      if (user.teachingGroupIds.isNotEmpty) {
        _loadUserGroup(user.teachingGroupIds.first);
      }
    }
  }
  
  Future<void> _loadUserGroup(String groupId) async {
    try {
      final response = await SupabaseConfig.client
          .from('groups')
          .select()
          .eq('id', groupId)
          .single();
      
      setState(() {
        _userGroup = CapoeiraGroup.fromMap(response);
        _venmoController.text = _userGroup?.venmoHandle ?? '';
      });
    } catch (e) {
      print('Error loading group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => _saveProfile(context, ref),
            child: const Text(
              'Save',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: currentUser.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('No user data'));
          }
          
          _initializeControllers(user);
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Picture Section
                  Center(
                    child: GestureDetector(
                      onTap: _selectProfilePicture,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                            backgroundImage: _getProfileImage(user),
                            child: _getProfileImage(user) == null
                                ? Text(
                                    user.capoeiraName.isNotEmpty 
                                        ? user.capoeiraName[0].toUpperCase() 
                                        : 'U',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Full Name
                  TextFormField(
                    controller: _fullNameController,
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
                  
                  // Capoeira Name
                  TextFormField(
                    controller: _capoeiraNameController,
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
                  
                  // Date of Birth
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
                  
                  // Group Name (read-only for now)
                  if (user.groupName != null) ...[
                    TextFormField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group',
                        border: OutlineInputBorder(),
                      ),
                      enabled: false, // Can't change group for now
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Venmo Handle (for teachers/group owners)
                  if (user.teachingGroupIds.isNotEmpty) ...[
                    TextFormField(
                      controller: _venmoController,
                      decoration: const InputDecoration(
                        labelText: 'Venmo Handle',
                        border: OutlineInputBorder(),
                        prefixText: '@',
                        hintText: 'your-venmo-handle',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Role Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          user.role == UserRole.teacher ? Icons.school : Icons.person,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Type',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              user.role == UserRole.teacher ? 'Teacher' : 'Student',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _saveProfile(context, ref),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
  
  ImageProvider? _getProfileImage(UserModel user) {
    if (_selectedImage != null) {
      return FileImage(File(_selectedImage!.path));
    } else if (user.profilePictureUrl != null) {
      return NetworkImage(user.profilePictureUrl!);
    }
    return null;
  }
  
  Future<void> _selectProfilePicture() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.cancel),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    
    if (source != null) {
      try {
        final pickedImage = await _imagePicker.pickImage(
          source: source,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        
        if (pickedImage != null) {
          setState(() {
            _selectedImage = pickedImage;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to select image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  
  Future<void> _saveProfile(BuildContext context, WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dateOfBirth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final user = ref.read(currentUserProvider).value!;
      
      String? profilePictureUrl;
      
      // Upload profile picture if selected
      if (_selectedImage != null) {
        profilePictureUrl = await R2StorageService.uploadProfilePicture(
          userId: user.id,
          imageFile: _selectedImage!,
        );
        
        if (profilePictureUrl == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to upload profile picture'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      // Prepare update data
      final updateData = <String, dynamic>{
        'fullName': _fullNameController.text,
        'capoeiraName': _capoeiraNameController.text,
        'date_of_birth': _dateOfBirth!.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Add profile picture URL if uploaded
      if (profilePictureUrl != null) {
        updateData['profilePictureUrl'] = profilePictureUrl;
      }
      
      // Update user document
      await SupabaseConfig.client
          .from('users')
          .update(updateData)
          .eq('id', user.id);
      
      // Update group Venmo if user has a group
      if (_userGroup != null && user.teachingGroupIds.isNotEmpty) {
        final venmoHandle = _venmoController.text.replaceAll('@', '');
        await SupabaseConfig.client
            .from('groups')
            .update({
          'venmo_handle': venmoHandle.isNotEmpty ? venmoHandle : null,
        })
            .eq('id', user.teachingGroupIds.first);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
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
    _venmoController.dispose();
    super.dispose();
  }
}