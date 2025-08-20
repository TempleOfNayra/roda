import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/application/group_controller.dart';
import 'package:roda/core/services/r2_storage_service.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/core/theme/roda_colors.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _nameController = TextEditingController();
  final _branchController = TextEditingController();
  final _cityController = TextEditingController();
  final _teacherTitleController = TextEditingController();
  final _teacherNameController = TextEditingController();
  final _lineageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venmoController = TextEditingController();
  
  CapoeiraStyle _selectedStyle = CapoeiraStyle.contemporanea;
  String _selectedTeacherTitle = 'Professor';
  bool _isLoading = false;
  XFile? _selectedHeaderImage;
  Uint8List? _headerImageBytes;

  final List<String> _teacherTitles = [
    'Mestre',
    'Contra-Mestre',
    'Professor',
    'Instrutor',
    'Monitor',
    'Graduado',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _branchController.dispose();
    _cityController.dispose();
    _teacherTitleController.dispose();
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

  void _showTeacherTitlePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 250,
        color: RodaColors.systemBackground,
        child: Column(
          children: [
            Container(
              height: 50,
              color: RodaColors.systemGrey6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    child: const Text('Done'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoPicker(
                itemExtent: 40,
                scrollController: FixedExtentScrollController(
                  initialItem: _teacherTitles.indexOf(_selectedTeacherTitle),
                ),
                onSelectedItemChanged: (index) {
                  setState(() {
                    _selectedTeacherTitle = _teacherTitles[index];
                  });
                },
                children: _teacherTitles.map((title) => Center(child: Text(title))).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _validateForm() {
    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      _showValidationError('Please enter a group name');
      return false;
    }
    if (_teacherNameController.text.trim().isEmpty) {
      _showValidationError('Please enter your teacher name');
      return false;
    }
    if (_cityController.text.trim().isEmpty) {
      _showValidationError('Please enter the city');
      return false;
    }
    return true;
  }

  void _showValidationError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Validation Error'),
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

  Future<void> _createGroup() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      final groupController = ref.read(groupControllerProvider);
      
      // Upload header image if selected
      String? headerImageUrl;
      if (_selectedHeaderImage != null && _headerImageBytes != null) {
        try {
          final tempGroupId = DateTime.now().millisecondsSinceEpoch.toString();
          headerImageUrl = await R2StorageService.uploadGroupImage(
            groupId: tempGroupId,
            imageFile: _selectedHeaderImage!,
            imageType: 'header',
          );
        } catch (e) {
          Logger.debug('Image upload failed, continuing without image: $e');
          // Continue without image if upload fails
          headerImageUrl = null;
        }
      }

      // Create the group
      await groupController.createGroupWithDetails(
        name: _nameController.text.trim(),
        branch: _branchController.text.trim().isEmpty ? null : _branchController.text.trim(),
        city: _cityController.text.trim(),
        teacherTitle: _selectedTeacherTitle,
        teacherFullName: _teacherNameController.text.trim(),
        capoeiraStyle: _selectedStyle,
        lineage: _lineageController.text.trim().isEmpty ? null : _lineageController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        venmoHandle: _venmoController.text.trim().isEmpty ? null : _venmoController.text.trim(),
        headerImageUrl: headerImageUrl,
      );

      // Invalidate the user groups provider to force refresh
      ref.invalidate(userGroupsProvider);
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Success'),
            content: const Text('Group created successfully!'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
        
        // Small delay to ensure database changes are committed
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate back to profile page where the group will be shown
        if (mounted) {
          context.go('/profile');
        }
      }
    } catch (e) {
      Logger.debug('Error creating group: $e');
      if (mounted) {
        final errorMessage = e is AppException 
          ? ExceptionMapper.getUserFriendlyMessage(e)
          : 'Failed to create group. Please try again.';
        
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(errorMessage),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Create New Group'),
      ),
      body: SingleChildScrollView(
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
                    color: RodaColors.systemGroupedBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: RodaColors.separator,
                      width: 2,
                    ),
                    image: _headerImageBytes != null
                      ? DecorationImage(
                          image: MemoryImage(_headerImageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                  ),
                  child: _headerImageBytes == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.photo_on_rectangle,
                            size: 48,
                            color: RodaColors.activeBlue,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Group Header Image',
                            style: const TextStyle(
                              color: RodaColors.activeBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to upload',
                            style: const TextStyle(
                              color: RodaColors.secondaryLabel,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : null,
                ),
              ),
              const SizedBox(height: 24),

              // Group Name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Group Name *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _nameController,
                    placeholder: 'e.g., ABADA, Senzala, Cordão de Ouro',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.group, color: RodaColors.secondaryLabel),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: RodaColors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Branch (optional)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Branch (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _branchController,
                    placeholder: 'e.g., SF, Oakland, Berkeley',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.building_2_fill, color: RodaColors.secondaryLabel),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: RodaColors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Teacher Title
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Title *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _showTeacherTitlePicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: RodaColors.separator),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: Icon(CupertinoIcons.book, color: RodaColors.secondaryLabel),
                          ),
                          Expanded(
                            child: Text(
                              _selectedTeacherTitle,
                              style: const TextStyle(color: RodaColors.label),
                            ),
                          ),
                          const Icon(CupertinoIcons.chevron_down, color: RodaColors.secondaryLabel),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Teacher Name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Teacher Name *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _teacherNameController,
                    placeholder: 'e.g., Mestre João Silva',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.person, color: RodaColors.secondaryLabel),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: RodaColors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // City
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'City *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _cityController,
                    placeholder: 'e.g., San Francisco, Rio de Janeiro',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.location, color: RodaColors.secondaryLabel),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: RodaColors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Capoeira Style
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Capoeira Style *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CupertinoSegmentedControl<CapoeiraStyle>(
                    children: Map.fromEntries(
                      CapoeiraStyle.values.map((style) => MapEntry(
                        style,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Text(
                            style.displayName,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      )),
                    ),
                    groupValue: _selectedStyle,
                    onValueChanged: (value) {
                      setState(() => _selectedStyle = value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lineage
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lineage/Linhagem (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _lineageController,
                    placeholder: 'e.g., Mestre Bimba, Mestre Pastinha',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.tree, color: RodaColors.secondaryLabel),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: RodaColors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _descriptionController,
                    placeholder: 'Tell us about your group...',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0, top: 8.0),
                      child: Icon(CupertinoIcons.doc_text, color: RodaColors.secondaryLabel),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: RodaColors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Venmo Handle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Venmo Handle (optional)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: RodaColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CupertinoTextField(
                    controller: _venmoController,
                    placeholder: '@your-venmo-handle',
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(CupertinoIcons.creditcard, color: RodaColors.secondaryLabel),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: RodaColors.separator),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Create Button
              CupertinoButton.filled(
                onPressed: _isLoading ? null : _createGroup,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CupertinoActivityIndicator(radius: 10),
                      )
                    : const Text(
                        'Create Group',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}