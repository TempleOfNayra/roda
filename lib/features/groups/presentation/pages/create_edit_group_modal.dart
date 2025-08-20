import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/application/group_controller.dart';
import 'package:roda/core/services/r2_storage_service.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/features/groups/providers/supabase_group_providers.dart';

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
  final _teacherNameController = TextEditingController();
  final _lineageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venmoController = TextEditingController();
  
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
    _teacherNameController.text = group.teacherFullName;
    _lineageController.text = group.lineage ?? '';
    _descriptionController.text = group.description ?? '';
    _venmoController.text = group.venmoHandle ?? '';
    _selectedStyle = group.capoeiraStyle;
    _selectedTeacherTitle = group.teacherTitle;
    _existingHeaderImageUrl = group.headerImageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _branchController.dispose();
    _cityController.dispose();
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
      final bytes = await image.readAsBytes();
      setState(() {
        _selectedHeaderImage = image;
        _headerImageBytes = bytes;
      });
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
      
      // Upload header image if selected
      String? headerImageUrl = _existingHeaderImageUrl;
      if (_selectedHeaderImage != null && _headerImageBytes != null) {
        try {
          final groupId = widget.groupId ?? DateTime.now().millisecondsSinceEpoch.toString();
          headerImageUrl = await R2StorageService.uploadGroupImage(
            groupId: groupId,
            imageFile: _selectedHeaderImage!,
            imageType: 'header',
          );
        } catch (e) {
          Logger.debug('Image upload failed, continuing: $e');
        }
      }

      if (isEditMode && widget.groupId != null && widget.existingGroup != null) {
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
        // Create new group
        await groupController.createGroupWithDetails(
          name: _nameController.text.trim(),
          branch: _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
          city: _cityController.text.trim().toUpperCase(),
          teacherTitle: _selectedTeacherTitle,
          teacherFullName: _teacherNameController.text.trim(),
          capoeiraStyle: _selectedStyle,
          lineage: _lineageController.text.trim().isEmpty ? null : _lineageController.text.trim(),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          venmoHandle: _venmoController.text.trim().isEmpty ? null : _venmoController.text.trim(),
          headerImageUrl: headerImageUrl,
        );
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
    return Material(
      type: MaterialType.transparency,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: CupertinoColors.systemBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                Text(
                  isEditMode ? 'Edit Group' : 'Create Group',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _isLoading ? null : _saveGroup,
                  child: _isLoading
                      ? const CupertinoActivityIndicator()
                      : Text(
                          isEditMode ? 'Save' : 'Create',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ),
          
          // Form content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Image Upload
                  GestureDetector(
                    onTap: _pickHeaderImage,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: CupertinoColors.systemGrey4,
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
                                  color: CupertinoColors.systemBlue,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add Group Header Image',
                                  style: TextStyle(
                                    color: CupertinoColors.systemBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tap to upload',
                                  style: TextStyle(
                                    color: CupertinoColors.systemGrey,
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
                                  color: CupertinoColors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Tap to change',
                                  style: TextStyle(
                                    color: CupertinoColors.white,
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

                  // Teacher Title
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showTitlePicker(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Capoeira Style *',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoSegmentedControl<CapoeiraStyle>(
                        groupValue: _selectedStyle,
                        onValueChanged: (value) {
                          setState(() => _selectedStyle = value);
                        },
                        children: Map.fromEntries(
                          CapoeiraStyle.values.map((style) => MapEntry(
                            style,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Text(
                                style.displayName,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          )),
                        ),
                      ),
                    ],
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
        ],
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
        color: CupertinoColors.systemGrey6,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: CupertinoColors.systemGrey6,
          width: 0,
        ),
      ),
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        decoration: TextDecoration.none,
      ),
      placeholderStyle: const TextStyle(
        color: CupertinoColors.placeholderText,
        decoration: TextDecoration.none,
      ),
    );
  }

  void _showTitlePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: CupertinoColors.systemBackground.resolveFrom(context),
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