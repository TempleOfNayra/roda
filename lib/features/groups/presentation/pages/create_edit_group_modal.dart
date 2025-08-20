import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:roda/features/teacher/presentation/widgets/google_places_address_field.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/application/group_controller.dart';
import 'package:roda/core/services/r2_storage_service.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:uuid/uuid.dart';

class CreateEditGroupModal extends ConsumerStatefulWidget {
  final String? groupId; // null for create, has value for edit
  final CapoeiraGroup? existingGroup; // null for create, has value for edit

  const CreateEditGroupModal({
    super.key,
    this.groupId,
    this.existingGroup,
  });

  @override
  ConsumerState<CreateEditGroupModal> createState() => _CreateEditGroupModalState();
}

class _CreateEditGroupModalState extends ConsumerState<CreateEditGroupModal> {
  final _nameController = TextEditingController();
  final _branchController = TextEditingController();
  final _cityController = TextEditingController();
  final _locationController = TextEditingController();
  final _teacherNameController = TextEditingController();
  final _lineageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venmoController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _emailController = TextEditingController();
  
  // Location data
  String? _locationAddress;
  String? _locationName;
  double? _latitude;
  double? _longitude;
  String? _placeId;
  
  CapoeiraStyle _selectedStyle = CapoeiraStyle.angola; // Changed default to angola
  String _selectedTeacherTitle = 'Professor';
  bool _isLoading = false;
  XFile? _selectedHeaderImage;
  Uint8List? _headerImageBytes;
  String? _existingHeaderImageUrl;
  XFile? _selectedLogoImage;
  Uint8List? _logoImageBytes;
  String? _existingLogoImageUrl;

  final List<String> _teacherTitles = [
    'Mestre',
    'Contra-Mestre', 
    'Professor',
    'Instrutor',
    'Monitor',
    'Graduado',
  ];

  bool get isEditMode => widget.existingGroup != null;
  
  @override
  void initState() {
    super.initState();
    if (isEditMode && widget.existingGroup != null) {
      _populateExistingData(widget.existingGroup!);
    }
  }

  String _extractNameWithoutTitle(String dbCapoeiraName) {
    Logger.debug('extractNameWithoutTitle input: "$dbCapoeiraName"');
    
    String nameOnly = dbCapoeiraName.trim();
    String nameLower = nameOnly.toLowerCase();
    
    // Remove any title prefix from the name (case-insensitive)
    for (String title in _teacherTitles) {
      String titleLower = title.toLowerCase();
      if (nameLower.startsWith('$titleLower ')) {
        nameOnly = nameOnly.substring(title.length + 1).trim();
        Logger.debug('Found and removed title "$title", result: "$nameOnly"');
        break;
      }
    }
    
    Logger.debug('extractNameWithoutTitle output: "$nameOnly"');
    return nameOnly;
  }

  void _populateExistingData(CapoeiraGroup group) {
    Logger.debug('=== POPULATING EXISTING DATA FOR EDIT ===');
    Logger.debug('Group name: ${group.name}, Teacher: ${group.teacherFullName}');
    
    _nameController.text = group.name;
    _branchController.text = group.branch ?? '';
    _cityController.text = group.city;
    if (group.locationAddress != null && group.locationAddress!.isNotEmpty) {
      _locationController.text = group.locationAddress!;
    }
    
    // Extract name without title using our debug function
    String nameForField = _extractNameWithoutTitle(group.teacherFullName);
    _teacherNameController.text = nameForField;
    _lineageController.text = group.lineage ?? '';
    _descriptionController.text = group.description ?? '';
    _venmoController.text = group.venmoHandle ?? '';
    _contactNumberController.text = group.contactNumber ?? '';
    _emailController.text = group.email ?? '';
    _selectedStyle = group.capoeiraStyle;
    _selectedTeacherTitle = group.teacherTitle;
    _existingHeaderImageUrl = group.headerImageUrl;
    _existingLogoImageUrl = group.logoImageUrl;
    
    // Location data
    _locationAddress = group.locationAddress;
    _locationName = group.locationName;
    _latitude = group.latitude;
    _longitude = group.longitude;
    _placeId = group.placeId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _branchController.dispose();
    _cityController.dispose();
    _locationController.dispose();
    _teacherNameController.dispose();
    _lineageController.dispose();
    _descriptionController.dispose();
    _venmoController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _pickLogoImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    
    if (image != null) {
      // Crop the image with square aspect ratio
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square for logo
        uiSettings: [
          IOSUiSettings(
            title: 'Crop Logo Image',
            cancelButtonTitle: 'Cancel',
            doneButtonTitle: 'Done',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: true,
            rotateClockwiseButtonHidden: true,
          ),
        ],
      );
      
      if (croppedFile != null) {
        final bytes = await croppedFile.readAsBytes();
        setState(() {
          _selectedLogoImage = XFile(croppedFile.path);
          _logoImageBytes = bytes;
        });
      }
    }
  }

  Future<void> _pickHeaderImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
    
    if (image != null) {
      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9), // 16:9 for header images
        uiSettings: [
          IOSUiSettings(
            title: 'Crop Header Image',
            cancelButtonTitle: 'Cancel',
            doneButtonTitle: 'Done',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            rotateButtonsHidden: true,
            rotateClockwiseButtonHidden: true,
          ),
        ],
      );
      
      if (croppedFile != null) {
        final bytes = await croppedFile.readAsBytes();
        setState(() {
          _selectedHeaderImage = XFile(croppedFile.path);
          _headerImageBytes = bytes;
        });
      }
    }
  }

  Future<void> _saveGroup() async {
    if (_nameController.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _teacherNameController.text.trim().isEmpty) {
      _showErrorDialog('Please fill in all required fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final groupController = ref.read(groupControllerProvider);
      
      if (isEditMode && widget.groupId != null && widget.existingGroup != null) {
        // For edit mode, upload images first since we have the group ID
        String? headerImageUrl = _existingHeaderImageUrl;
        String? logoImageUrl = _existingLogoImageUrl;
        
        if (_selectedHeaderImage != null && _headerImageBytes != null) {
          try {
            headerImageUrl = await R2StorageService.uploadGroupImage(
              groupId: widget.groupId!,
              imageFile: _selectedHeaderImage!,
              imageType: 'header',
            );
            Logger.debug('Header image uploaded successfully: $headerImageUrl');
          } catch (e) {
            Logger.debug('Header image upload failed, continuing: $e');
          }
        }
        
        if (_selectedLogoImage != null && _logoImageBytes != null) {
          try {
            logoImageUrl = await R2StorageService.uploadGroupImage(
              groupId: widget.groupId!,
              imageFile: _selectedLogoImage!,
              imageType: 'logo',
            );
            Logger.debug('Logo image uploaded successfully: $logoImageUrl');
          } catch (e) {
            Logger.debug('Logo image upload failed, continuing: $e');
          }
        }
        // Create updated group object
        final updatedGroup = CapoeiraGroup(
          id: widget.existingGroup!.id,
          name: _nameController.text.trim(),
          branch: _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
          displayName: _branchController.text.trim().isEmpty 
              ? _nameController.text.trim()
              : '${_nameController.text.trim()} ${_branchController.text.trim()}',
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          city: _cityController.text.trim().toUpperCase(),
          locationAddress: _locationAddress ?? (_locationController.text.trim().isEmpty ? null : _locationController.text.trim()),
          locationName: _locationName,
          latitude: _latitude,
          longitude: _longitude,
          placeId: _placeId,
          teacherTitle: _selectedTeacherTitle,
          teacherFullName: '$_selectedTeacherTitle ${_teacherNameController.text.trim()}',
          capoeiraStyle: _selectedStyle,
          lineage: _lineageController.text.trim().isEmpty ? null : _lineageController.text.trim(),
          venmoHandle: _venmoController.text.trim().isEmpty ? null : _venmoController.text.trim(),
          adminIds: widget.existingGroup!.adminIds,
          teacherIds: widget.existingGroup!.teacherIds,
          memberIds: widget.existingGroup!.memberIds,
          createdBy: widget.existingGroup!.createdBy,
          teacherProfilePicture: widget.existingGroup!.teacherProfilePicture,
          headerImageUrl: headerImageUrl,
          logoImageUrl: logoImageUrl,
          contactNumber: _contactNumberController.text.trim().isEmpty ? null : _contactNumberController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          announcements: widget.existingGroup!.announcements,
          createdAt: widget.existingGroup!.createdAt,
          isActive: widget.existingGroup!.isActive,
        );
        
        await groupController.updateGroup(updatedGroup);
        
        // Invalidate the group provider to force refresh
        ref.invalidate(groupByIdProvider(widget.groupId!));
      } else {
        // Create new group - first without image to get the ID
        final createdGroup = await groupController.createGroupWithDetails(
          name: _nameController.text.trim(),
          branch: _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
          city: _cityController.text.trim().toUpperCase(),
          locationAddress: _locationAddress ?? (_locationController.text.trim().isEmpty ? null : _locationController.text.trim()),
          locationName: _locationName,
          latitude: _latitude,
          longitude: _longitude,
          placeId: _placeId,
          teacherTitle: _selectedTeacherTitle,
          teacherFullName: '$_selectedTeacherTitle ${_teacherNameController.text.trim()}',
          capoeiraStyle: _selectedStyle,
          lineage: _lineageController.text.trim().isEmpty ? null : _lineageController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          venmoHandle: _venmoController.text.trim().isEmpty ? null : _venmoController.text.trim(),
          contactNumber: _contactNumberController.text.trim().isEmpty ? null : _contactNumberController.text.trim(),
          email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
          headerImageUrl: null, // Don't pass image URLs yet
          logoImageUrl: null,
        );
        
        // Now upload images if selected, using the real group ID
        String? headerImageUrl;
        String? logoImageUrl;
        
        if (_selectedHeaderImage != null && _headerImageBytes != null) {
          try {
            headerImageUrl = await R2StorageService.uploadGroupImage(
              groupId: createdGroup.id,
              imageFile: _selectedHeaderImage!,
              imageType: 'header',
            );
            Logger.debug('Header image uploaded successfully: $headerImageUrl');
          } catch (e) {
            Logger.debug('Header image upload failed: $e');
          }
        }
        
        if (_selectedLogoImage != null && _logoImageBytes != null) {
          try {
            logoImageUrl = await R2StorageService.uploadGroupImage(
              groupId: createdGroup.id,
              imageFile: _selectedLogoImage!,
              imageType: 'logo',
            );
            Logger.debug('Logo image uploaded successfully: $logoImageUrl');
          } catch (e) {
            Logger.debug('Logo image upload failed: $e');
          }
        }
        
        // Update the group with image URLs if any were uploaded
        if (headerImageUrl != null || logoImageUrl != null) {
          final updatedGroup = CapoeiraGroup(
            id: createdGroup.id,
            name: createdGroup.name,
            branch: createdGroup.branch,
            displayName: createdGroup.displayName,
            description: createdGroup.description,
            city: createdGroup.city,
            locationAddress: createdGroup.locationAddress,
            locationName: createdGroup.locationName,
            latitude: createdGroup.latitude,
            longitude: createdGroup.longitude,
            placeId: createdGroup.placeId,
            teacherTitle: createdGroup.teacherTitle,
            teacherFullName: createdGroup.teacherFullName,
            capoeiraStyle: createdGroup.capoeiraStyle,
            lineage: createdGroup.lineage,
            venmoHandle: createdGroup.venmoHandle,
            adminIds: createdGroup.adminIds,
            teacherIds: createdGroup.teacherIds,
            memberIds: createdGroup.memberIds,
            createdBy: createdGroup.createdBy,
            teacherProfilePicture: createdGroup.teacherProfilePicture,
            headerImageUrl: headerImageUrl ?? createdGroup.headerImageUrl,
            logoImageUrl: logoImageUrl ?? createdGroup.logoImageUrl,
            contactNumber: createdGroup.contactNumber,
            email: createdGroup.email,
            announcements: createdGroup.announcements,
            createdAt: createdGroup.createdAt,
            isActive: createdGroup.isActive,
          );
          
          await groupController.updateGroup(updatedGroup);
          Logger.debug('Group updated with images');
        }
      }

      // Invalidate the user groups provider to force refresh
      ref.invalidate(userGroupsProvider);
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      Logger.error('Error saving group', e);
      if (mounted) {
        final errorMessage = e is AppException 
          ? ExceptionMapper.getUserFriendlyMessage(e)
          : 'Failed to save group. Please try again.';
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(isEditMode ? 'Edit Group' : 'Create Group'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _saveGroup,
          child: _isLoading
              ? const CupertinoActivityIndicator()
              : Text(
                  isEditMode ? 'Save' : 'Create',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                  // Header Image Upload
                  GestureDetector(
                    onTap: _pickHeaderImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: RodaColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: RodaColors.systemGrey4,
                          width: 1,
                        ),
                        image: _headerImageBytes != null
                            ? DecorationImage(
                                image: MemoryImage(_headerImageBytes!),
                                fit: BoxFit.cover,
                              )
                            : _existingHeaderImageUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(_existingHeaderImageUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                      ),
                      child: (_headerImageBytes == null && _existingHeaderImageUrl == null)
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  CupertinoIcons.photo_on_rectangle,
                                  size: 48,
                                  color: RodaColors.activeBlue,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add Group Header Image',
                                  style: TextStyle(
                                    color: RodaColors.activeBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap to upload',
                                  style: TextStyle(
                                    color: RodaColors.systemGrey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              alignment: Alignment.bottomRight,
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: RodaColors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tap to change',
                                  style: TextStyle(
                                    color: RodaColors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Logo Image Upload
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickLogoImage,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: RodaColors.systemGrey6,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: RodaColors.systemGrey4,
                              width: 1,
                            ),
                            image: _logoImageBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(_logoImageBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : _existingLogoImageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(_existingLogoImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: (_logoImageBytes == null && _existingLogoImageUrl == null)
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      CupertinoIcons.photo_on_rectangle,
                                      size: 24,
                                      color: RodaColors.activeBlue,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Logo',
                                      style: TextStyle(
                                        color: RodaColors.activeBlue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Optional group logo (square format)\nWill display on group header',
                          style: TextStyle(
                            color: RodaColors.systemGrey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Group Name
                  _buildTextField(
                    controller: _nameController,
                    placeholder: 'Group Name *',
                    prefix: const Icon(CupertinoIcons.group, size: 20),
                    textCapitalization: TextCapitalization.words,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),

                  // Branch
                  _buildTextField(
                    controller: _branchController,
                    placeholder: 'Branch (optional)',
                    prefix: const Icon(CupertinoIcons.location_circle, size: 20),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // City - Always uppercase
                  _buildTextField(
                    controller: _cityController,
                    placeholder: 'City *',
                    prefix: const Icon(CupertinoIcons.location, size: 20),
                    textCapitalization: TextCapitalization.characters, // This makes it uppercase
                    inputFormatters: [
                      UpperCaseTextFormatter(), // Custom formatter to ensure uppercase
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Physical Location (Google Places)
                  _buildLocationPicker(),
                  const SizedBox(height: 16),

                  // Teacher Title and Name Row
                  Row(
                    children: [
                      // Title Picker (fixed width)
                      SizedBox(
                        width: 140,
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => _showTitlePicker(),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: RodaColors.systemGrey6,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    _selectedTeacherTitle,
                                    style: const TextStyle(fontSize: 16),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(CupertinoIcons.chevron_down, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Teacher Name Field (expandable)
                      Expanded(
                        child: _buildTextField(
                          controller: _teacherNameController,
                          placeholder: 'Capoeira Name *',
                          textCapitalization: TextCapitalization.words,
                          autocorrect: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Capoeira Style
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showStylePicker(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RodaColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(CupertinoIcons.music_note, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                _selectedStyle.displayName,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          const Icon(
                            CupertinoIcons.chevron_down,
                            size: 20,
                            color: RodaColors.systemGrey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lineage
                  _buildTextField(
                    controller: _lineageController,
                    placeholder: 'Lineage/Linhagem (optional)',
                    prefix: const Icon(CupertinoIcons.tree, size: 20),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  _buildTextField(
                    controller: _descriptionController,
                    placeholder: 'Description (optional)',
                    prefix: const Icon(CupertinoIcons.doc_text, size: 20),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // Venmo Handle
                  _buildTextField(
                    controller: _venmoController,
                    placeholder: 'Venmo Handle (optional)',
                    prefix: const Icon(CupertinoIcons.at, size: 20),
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  
                  // Contact Number
                  _buildTextField(
                    controller: _contactNumberController,
                    placeholder: 'Contact Number (optional)',
                    prefix: const Icon(CupertinoIcons.phone, size: 20),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [PhoneNumberFormatter()],
                    autocorrect: false,
                  ),
                  const SizedBox(height: 16),
                  
                  // Email
                  _buildTextField(
                    controller: _emailController,
                    placeholder: 'Email (optional)',
                    prefix: const Icon(CupertinoIcons.mail, size: 20),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String placeholder,
    Widget? prefix,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    bool autocorrect = true,
  }) {
    return CupertinoTextField(
      controller: controller,
      placeholder: placeholder,
      prefix: prefix != null
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: prefix,
            )
          : null,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: RodaColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: RodaColors.systemGrey6,
          width: 0,
        ),
      ),
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      keyboardType: keyboardType,
      autocorrect: autocorrect,
    );
  }

  Widget _buildLocationPicker() {
    return GooglePlacesAddressField(
      controller: _locationController,
      hint: 'Physical Location (optional)',
      onLocationSelected: (address, lat, lng) {
        setState(() {
          _locationAddress = address;
          _locationName = address; // Use the address as the name for now
          _latitude = lat;
          _longitude = lng;
        });
      },
    );
  }

  void _showStylePicker() {
    // Remove any existing focus before showing picker
    FocusScope.of(context).unfocus();
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: RodaColors.systemBackground,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: CapoeiraStyle.values.indexOf(_selectedStyle),
                ),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedStyle = CapoeiraStyle.values[index];
                  });
                },
                children: CapoeiraStyle.values
                    .map((style) => Center(
                          child: Text(style.displayName),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showTitlePicker() {
    // Remove any existing focus before showing picker
    FocusScope.of(context).unfocus();
    
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: RodaColors.systemBackground,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                CupertinoButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Don't set focus anywhere after closing
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 32,
                scrollController: FixedExtentScrollController(
                  initialItem: _teacherTitles.indexOf(_selectedTeacherTitle),
                ),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedTeacherTitle = _teacherTitles[index];
                  });
                },
                children: _teacherTitles.map((title) => Text(title)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom formatter to ensure uppercase text
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// Phone number formatter for US numbers
class PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digits
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    
    // Limit to 10 digits
    final truncated = digitsOnly.length > 10 ? digitsOnly.substring(0, 10) : digitsOnly;
    
    // Format as (XXX) XXX-XXXX
    String formatted = '';
    for (int i = 0; i < truncated.length; i++) {
      if (i == 0) formatted += '(';
      if (i == 3) formatted += ') ';
      if (i == 6) formatted += '-';
      formatted += truncated[i];
    }
    
    // Calculate new cursor position
    int cursorPosition = formatted.length;
    
    // If user is deleting, adjust cursor position
    if (oldValue.text.length > newValue.text.length) {
      cursorPosition = newValue.selection.baseOffset;
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}