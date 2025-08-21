import 'package:flutter/cupertino.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:roda/features/groups/services/group_media_service.dart';

class MediaViewerPage extends StatefulWidget {
  final List<GroupMedia> mediaItems;
  final int initialIndex;
  
  const MediaViewerPage({
    super.key,
    required this.mediaItems,
    required this.initialIndex,
  });
  
  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: RodaColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: RodaColors.black.withValues(alpha: 0.8),
        border: null,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(
            CupertinoIcons.xmark,
            color: RodaColors.white,
          ),
        ),
        middle: Text(
          '${_currentIndex + 1} / ${widget.mediaItems.length}',
          style: const TextStyle(color: RodaColors.white),
        ),
      ),
      child: SafeArea(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.mediaItems.length,
          onPageChanged: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final item = widget.mediaItems[index];
            return Stack(
              children: [
                InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: item.mediaType == 'video'
                        ? _buildVideoPlayer(item)
                        : _buildImageViewer(item),
                  ),
                ),
                // Caption overlay
                if (item.caption != null && item.caption!.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            RodaColors.black.withValues(alpha: 0.8),
                            RodaColors.black.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        item.caption!,
                        style: const TextStyle(
                          color: RodaColors.white,
                          fontSize: 16,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildImageViewer(GroupMedia item) {
    return Image.network(
      item.url,
      fit: BoxFit.contain,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CupertinoActivityIndicator(
            radius: 20,
            color: RodaColors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: RodaColors.systemGrey,
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Failed to load image',
                style: TextStyle(color: RodaColors.systemGrey),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildVideoPlayer(GroupMedia item) {
    // For now, just show a placeholder with play button
    // You can integrate a video player package later
    return Container(
      color: RodaColors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.play_circle_fill,
              size: 80,
              color: RodaColors.white.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            const Text(
              'Video playback coming soon',
              style: TextStyle(
                color: RodaColors.systemGrey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}