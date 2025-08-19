import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roda/core/widgets/safe_scaffold.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/application/group_controller.dart';
import 'package:roda/data/repositories/storage_repository.dart';
import 'package:roda/data/core/db_exceptions.dart';
import 'package:roda/core/utils/logger.dart';

class CreateGroupPage extends ConsumerStatefulWidget {
  const CreateGroupPage({super.key});

  @override
  ConsumerState<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends ConsumerState<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final groupController = ref.read(groupControllerProvider);
      
      // Upload header image if selected
      String? headerImageUrl;
      if (_selectedHeaderImage != null && _headerImageBytes != null) {
        try {
          final storageRepository = ref.read(storageRepositoryProvider);
          final tempGroupId = DateTime.now().millisecondsSinceEpoch.toString();
          headerImageUrl = await storageRepository.uploadGroupImage(
            groupId: tempGroupId,
            imageData: _headerImageBytes!,
            fileExtension: _selectedHeaderImage!.name.split('.').last,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully!')),
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
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
    final theme = Theme.of(context);
    
    return SafeScaffold(
      appBar: AppBar(
        title: const Text('Create New Group'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Image Upload
              GestureDetector(
                onTap: _pickHeaderImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.3),
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
                            Icons.add_photo_alternate,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add Group Header Image',
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to upload',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
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
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name *',
                  hintText: 'e.g., ABADA, Senzala, Cordão de Ouro',
                  prefixIcon: Icon(Icons.group),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Branch (optional)
              TextFormField(
                controller: _branchController,
                decoration: const InputDecoration(
                  labelText: 'Branch (optional)',
                  hintText: 'e.g., SF, Oakland, Berkeley',
                  prefixIcon: Icon(Icons.location_city),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Teacher Title
              DropdownButtonFormField<String>(
                value: _selectedTeacherTitle,
                decoration: const InputDecoration(
                  labelText: 'Your Title *',
                  prefixIcon: Icon(Icons.school),
                ),
                items: _teacherTitles.map((title) {
                  return DropdownMenuItem(
                    value: title,
                    child: Text(title),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedTeacherTitle = value);
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select your title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Teacher Name
              TextFormField(
                controller: _teacherNameController,
                decoration: const InputDecoration(
                  labelText: 'Your Teacher Name *',
                  hintText: 'e.g., Mestre João Silva',
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your teacher name';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // City
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City *',
                  hintText: 'e.g., San Francisco, Rio de Janeiro',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the city';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Capoeira Style
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Capoeira Style *',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: CapoeiraStyle.values.map((style) {
                      return ChoiceChip(
                        label: Text(style.displayName),
                        selected: _selectedStyle == style,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedStyle = style);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lineage
              TextFormField(
                controller: _lineageController,
                decoration: const InputDecoration(
                  labelText: 'Lineage/Linhagem (optional)',
                  hintText: 'e.g., Mestre Bimba, Mestre Pastinha',
                  prefixIcon: Icon(Icons.account_tree),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Tell us about your group...',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // Venmo Handle
              TextFormField(
                controller: _venmoController,
                decoration: const InputDecoration(
                  labelText: 'Venmo Handle (optional)',
                  hintText: '@your-venmo-handle',
                  prefixIcon: Icon(Icons.payment),
                ),
              ),
              const SizedBox(height: 32),

              // Create Button
              FilledButton(
                onPressed: _isLoading ? null : _createGroup,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
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
      ),
    );
  }
}