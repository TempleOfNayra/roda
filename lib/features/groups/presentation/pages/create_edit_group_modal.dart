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
  
  // Location data
  String? _locationAddress;
  String? _locationName;
  double? _latitude;
  double? _longitude;
  String? _placeId;
  
  CapoeiraStyle _selectedStyle = CapoeiraStyle.contemporanea;
  String _selectedTeacherTitle = 'Professor';
  bool _isLoading = false;
  XFile? _selectedHeaderImage;
  Uint8List? _headerImageBytes;
  String? _existingHeaderImageUrl;

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

  void _populateExistingData(CapoeiraGroup group) {
    _nameController.text = group.name;
    _branchController.text = group.branch ?? '';
    _cityController.text = group.city;
    if (group.locationAddress != null && group.locationAddress!.isNotEmpty) {
      _locationController.text = group.locationAddress!;
    }
    _teacherNameController.text = group.teacherFullName;
    _lineageController.text = group.lineage ?? '';
    _descriptionController.text = group.description ?? '';
    _venmoController.text = group.venmoHandle ?? '';
    _selectedStyle = group.capoeiraStyle;
    _selectedTeacherTitle = group.teacherTitle;
    _existingHeaderImageUrl = group.headerImageUrl;
    
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
    super.dispose();
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
        // For edit mode, upload image first since we have the group ID
        String? headerImageUrl = _existingHeaderImageUrl;
        if (_selectedHeaderImage != null && _headerImageBytes != null) {
          try {
            headerImageUrl = await R2StorageService.uploadGroupImage(
              groupId: widget.groupId!,
              imageFile: _selectedHeaderImage!,
              imageType: 'header',
            );
            Logger.debug('Header image uploaded successfully: $headerImageUrl');
          } catch (e) {
            Logger.debug('Image upload failed, continuing: $e');
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
          teacherFullName: _teacherNameController.text.trim(),
          capoeiraStyle: _selectedStyle,
          lineage: _lineageController.text.trim().isEmpty ? null : _lineageController.text.trim(),
          venmoHandle: _venmoController.text.trim().isEmpty ? null : _venmoController.text.trim(),
          adminIds: widget.existingGroup!.adminIds,
          teacherIds: widget.existingGroup!.teacherIds,
          memberIds: widget.existingGroup!.memberIds,
          createdBy: widget.existingGroup!.createdBy,
          teacherProfilePicture: widget.existingGroup!.teacherProfilePicture,
          headerImageUrl: headerImageUrl,
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
          teacherFullName: _teacherNameController.text.trim(),
          capoeiraStyle: _selectedStyle,
          lineage: _lineageController.text.trim().isEmpty ? null : _lineageController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          venmoHandle: _venmoController.text.trim().isEmpty ? null : _venmoController.text.trim(),
          headerImageUrl: null, // Don't pass image URL yet
        );
        
        // Now upload image if selected, using the real group ID
        if (_selectedHeaderImage != null && _headerImageBytes != null) {
          try {
            Logger.debug('Attempting to upload header image for group: ${createdGroup.id}');
            Logger.debug('Image file: ${_selectedHeaderImage!.name}');
            
            final headerImageUrl = await R2StorageService.uploadGroupImage(
              groupId: createdGroup.id,
              imageFile: _selectedHeaderImage!,
              imageType: 'header',
            );
            
            Logger.debug('R2 upload returned URL: $headerImageUrl');
            
            if (headerImageUrl != null) {
              Logger.debug('Header image uploaded successfully: $headerImageUrl');
              
              // Update the group with the header image URL
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
                headerImageUrl: headerImageUrl,
                announcements: createdGroup.announcements,
                createdAt: createdGroup.createdAt,
                isActive: createdGroup.isActive,
              );
              
              await groupController.updateGroup(updatedGroup);
              Logger.debug('Group updated with header image');
            }
          } catch (e) {
            Logger.debug('Image upload failed after group creation: $e');
            // Group is already created, just continue without image
          }
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
                  const SizedBox(height: 24),

                  // Group Name
                  _buildTextField(
                    controller: _nameController,
                    placeholder: 'Group Name *',
                    prefix: const Icon(CupertinoIcons.group, size: 20),
                    textCapitalization: TextCapitalization.words,
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

                  // Teacher Title
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showTitlePicker(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: RodaColors.systemGrey6,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(CupertinoIcons.person_badge_plus, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Title: $_selectedTeacherTitle',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_down, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Teacher Name
                  _buildTextField(
                    controller: _teacherNameController,
                    placeholder: 'Your Teacher Name *',
                    prefix: const Icon(CupertinoIcons.person, size: 20),
                    textCapitalization: TextCapitalization.words,
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
                    prefix: const Icon(CupertinoIcons.money_dollar, size: 20),
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