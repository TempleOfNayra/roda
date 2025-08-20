import 'package:flutter/cupertino.dart';
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
import 'package:roda/core/utils/logger.dart';
import 'package:roda/core/theme/roda_colors.dart';

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
      Logger.debug('Error loading group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);
    
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Edit Profile'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.xmark),
          onPressed: () => context.pop(),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : () => _saveProfile(context, ref),
          child: const Text(
            'Save',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: currentUser.when(
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
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: RodaColors.activeBlue.withOpacity(0.2),
                              image: _getProfileImage(user) != null
                                  ? DecorationImage(
                                      image: _getProfileImage(user)!,
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _getProfileImage(user) == null
                                ? Center(
                                    child: Text(
                                      user.capoeiraName.isNotEmpty 
                                          ? user.capoeiraName[0].toUpperCase() 
                                          : 'U',
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: RodaColors.activeBlue,
                                      ),
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
                                color: RodaColors.activeBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.camera_fill,
                                size: 20,
                                color: RodaColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Full Name
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Full Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _fullNameController,
                        placeholder: 'Enter your full name',
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: RodaColors.systemGrey4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Capoeira Name
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Capoeira Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: _capoeiraNameController,
                        placeholder: 'Enter your Capoeira name',
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: RodaColors.systemGrey4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Group', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        CupertinoTextField(
                          controller: _groupNameController,
                          enabled: false,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: RodaColors.systemGrey4),
                            borderRadius: BorderRadius.circular(8),
                            color: RodaColors.systemGrey6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Venmo Handle (for teachers/group owners)
                  if (user.teachingGroupIds.isNotEmpty) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Venmo Handle', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        CupertinoTextField(
                          controller: _venmoController,
                          placeholder: 'your-venmo-handle',
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 12),
                            child: Text('@'),
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: RodaColors.systemGrey4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  // Role Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: RodaColors.systemGrey6,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          user.role == UserRole.teacher ? CupertinoIcons.book : CupertinoIcons.person,
                          color: RodaColors.activeBlue,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Account Type',
                              style: TextStyle(
                                fontSize: 12,
                                color: RodaColors.systemGrey,
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
                    child: CupertinoButton.filled(
                      onPressed: _isLoading ? null : () => _saveProfile(context, ref),
                      borderRadius: BorderRadius.circular(8),
                      child: _isLoading
                          ? const CupertinoActivityIndicator(color: RodaColors.white)
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
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        ),
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
    final source = await showCupertinoModalPopup<ImageSource>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Select Profile Picture'),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Take Photo'),
            onPressed: () => Navigator.pop(context, ImageSource.camera),
          ),
          CupertinoActionSheetAction(
            child: const Text('Choose from Gallery'),
            onPressed: () => Navigator.pop(context, ImageSource.gallery),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
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
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Error'),
              content: Text('Failed to select image: $e'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
        }
      }
    }
  }
  
  
  Future<void> _saveProfile(BuildContext context, WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_dateOfBirth == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Missing Information'),
          content: const Text('Please select your date of birth'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
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
          // ignore: use_build_context_synchronously
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Upload Failed'),
              content: const Text('Failed to upload profile picture'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
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
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text('Profile updated successfully'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to update profile: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
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