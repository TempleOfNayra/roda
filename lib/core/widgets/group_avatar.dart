import 'package:flutter/cupertino.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:roda/core/theme/roda_colors.dart';

class GroupAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final double borderRadius;
  final String? name; // For fallback initials
  
  const GroupAvatar({
    super.key,
    this.imageUrl,
    this.size = 60,
    this.borderRadius = 12,
    this.name,
  });

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    // For groups, take first letter of first two words if available
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: RodaColors.systemGrey5,
        border: Border.all(
          color: RodaColors.systemGrey4,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              placeholder: (context, url) => const Center(
                child: CupertinoActivityIndicator(),
              ),
              errorWidget: (context, url, error) => _buildFallback(),
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    if (name != null && name!.isNotEmpty) {
      return Container(
        color: RodaColors.systemGrey5,
        child: Center(
          child: Text(
            _getInitials(name!),
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w600,
              color: RodaColors.systemGrey,
            ),
          ),
        ),
      );
    }
    return Container(
      color: RodaColors.systemGrey5,
      child: Icon(
        CupertinoIcons.group_solid,
        size: size * 0.4,
        color: RodaColors.systemGrey,
      ),
    );
  }
}