import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:roda/core/models/capoeira_group.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:roda/core/utils/logger.dart';
import 'package:roda/core/services/r2_storage_service.dart';
import 'package:roda/features/groups/services/group_media_service.dart';
import 'package:roda/features/groups/presentation/widgets/media_viewer_page.dart';

class GroupMediaTab extends ConsumerStatefulWidget {
  final CapoeiraGroup group;
  final bool isAdmin;
  
  const GroupMediaTab({
    super.key,
    required this.group,
    required this.isAdmin,
  });

  @override
  ConsumerState<GroupMediaTab> createState() => _GroupMediaTabState();
}

class _GroupMediaTabState extends ConsumerState<GroupMediaTab> {
  bool _isUploading = false;
  
  Future<void> _showMediaOptions() async {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: const Text('Add Media'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _captureMedia(ImageSource.camera, isVideo: false);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.camera, size: 20),
                SizedBox(width: 8),
                Text('Take Photo'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _captureMedia(ImageSource.camera, isVideo: true);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.video_camera, size: 20),
                SizedBox(width: 8),
                Text('Record Video'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _captureMedia(ImageSource.gallery, isVideo: false);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.photo, size: 20),
                SizedBox(width: 8),
                Text('Choose Photo from Gallery'),
              ],
            ),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _captureMedia(ImageSource.gallery, isVideo: true);
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.videocam, size: 20),
                SizedBox(width: 8),
                Text('Choose Video from Gallery'),
              ],
            ),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
  
  Future<void> _captureMedia(ImageSource source, {required bool isVideo}) async {
    try {
      final ImagePicker picker = ImagePicker();
      XFile? file;
      
      if (isVideo) {
        file = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(minutes: 5), // 5 minute max
        );
      } else {
        file = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          imageQuality: 85,
        );
      }
      
      if (file != null) {
        // Show caption dialog
        final String? caption = await _showCaptionDialog(file, isVideo);
        
        // caption will never be null now (either empty string or text)
        if (caption == null) return; // Just in case dialog is dismissed
        
        setState(() => _isUploading = true);
        
        // Use dedicated group media upload method
        final url = await R2StorageService.uploadGroupMedia(
          groupId: widget.group.id,
          mediaFile: file,
          isVideo: isVideo,
        );
        
        if (url != null) {
          // Save to database with caption
          final service = ref.read(groupMediaServiceProvider);
          final saved = await service.saveMedia(
            groupId: widget.group.id,
            url: url,
            mediaType: isVideo ? 'video' : 'photo',
            caption: caption.isNotEmpty ? caption : null,
          );
          
          if (saved != null) {
            // Refresh the media list
            ref.invalidate(groupMediaStreamProvider(widget.group.id));
            Logger.debug('Media uploaded and saved successfully: $url');
          } else {
            throw Exception('Failed to save media to database');
          }
        } else {
          throw Exception('Upload failed - no URL returned');
        }
      }
    } catch (e) {
      Logger.debug('Error capturing media: $e');
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Upload Failed'),
            content: Text('Failed to upload media: $e'),
            actions: [
              CupertinoDialogAction(
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
  
  Future<String?> _showCaptionDialog(XFile file, bool isVideo) async {
    final TextEditingController captionController = TextEditingController();
    
    return showCupertinoDialog<String>(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(isVideo ? 'Add Caption to Video' : 'Add Caption to Photo'),
        content: Container(
          padding: const EdgeInsets.only(top: 16),
          height: 120, // Fixed height to prevent scrolling
          child: CupertinoTextField(
            controller: captionController,
            placeholder: 'Enter caption (optional)',
            maxLines: 4,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            autofocus: true,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey6,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Skip'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context, captionController.text),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }
  
  void _openMediaViewer(List<GroupMedia> mediaItems, int index) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        fullscreenDialog: true,
        builder: (context) => MediaViewerPage(
          mediaItems: mediaItems,
          initialIndex: index,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final mediaAsync = ref.watch(groupMediaStreamProvider(widget.group.id));
    
    return mediaAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, stack) {
        Logger.debug('Error loading media: $error');
        return Center(
          child: Text('Error loading media: $error'),
        );
      },
      data: (mediaItems) {
        Logger.debug('Loaded ${mediaItems.length} media items for group ${widget.group.id}');
        if (mediaItems.isEmpty && !_isUploading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              CupertinoIcons.photo_on_rectangle,
              size: 64,
              color: RodaColors.systemGrey,
            ),
            const SizedBox(height: 16),
            const Text(
              'No media yet',
              style: TextStyle(
                fontSize: 18,
                color: RodaColors.systemGrey,
              ),
            ),
            if (widget.isAdmin) ...[
              const SizedBox(height: 24),
              CupertinoButton(
                color: RodaColors.primary,
                onPressed: _showMediaOptions,
                child: const Text(
                  'Add Photo or Video',
                  style: TextStyle(color: RodaColors.white),
                ),
              ),
            ],
          ],
        ),
      );
    }
    
    return Stack(
      children: [
        Column(
          children: [
            if (widget.isAdmin)
              Padding(
                padding: const EdgeInsets.all(16),
                child: CupertinoButton(
                  color: RodaColors.primary,
                  onPressed: _isUploading ? null : _showMediaOptions,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        CupertinoIcons.add_circled,
                        color: RodaColors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isUploading ? 'Uploading...' : 'Add Photo or Video',
                        style: const TextStyle(color: RodaColors.white),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: mediaItems.length,
                itemBuilder: (context, index) {
                  final item = mediaItems[index];
                  return GestureDetector(
                    onTap: () => _openMediaViewer(mediaItems, index),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: RodaColors.systemGrey5,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    CupertinoIcons.exclamationmark_triangle,
                                    color: RodaColors.systemGrey,
                                  ),
                                );
                              },
                            ),
                          ),
                          if (item.mediaType == 'video')
                            const Center(
                              child: Icon(
                                CupertinoIcons.play_circle_fill,
                                size: 40,
                                color: RodaColors.white,
                              ),
                            ),
                          // Caption indicator
                          if (item.caption != null && item.caption!.isNotEmpty)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              right: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: RodaColors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.caption!,
                                  style: const TextStyle(
                                    color: RodaColors.white,
                                    fontSize: 10,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        if (_isUploading)
          Container(
            color: RodaColors.black.withValues(alpha: 0.5),
            child: const Center(
              child: CupertinoActivityIndicator(
                radius: 20,
              ),
            ),
          ),
      ],
    );
      },
    );
  }
}