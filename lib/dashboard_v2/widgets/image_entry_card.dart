import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/image_storage_service.dart';
import 'package:myapp/services/image_storage_sync_service.dart';
import 'package:myapp/utils/category_colors.dart';

// CP: Converted to StatefulWidget to cache the FutureBuilder future and prevent
// redundant async operations on every rebuild.
class ImageEntryCard extends StatefulWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? categoryColor;

  const ImageEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelected = false,
    this.categoryColor,
  });

  @override
  State<ImageEntryCard> createState() => _ImageEntryCardState();
}

class _ImageEntryCardState extends State<ImageEntryCard> {
  // CP: Cache the future to prevent recreating on every build
  late Future<({String? localPath, String? downloadUrl})> _imageSourceFuture;
  bool _downloadTriggered = false;

  @override
  void initState() {
    super.initState();
    _imageSourceFuture = _getImageSource();
  }

  @override
  void didUpdateWidget(ImageEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // CP: Only refresh if the entry's image paths changed
    if (oldWidget.entry.imagePath != widget.entry.imagePath ||
        oldWidget.entry.cloudImagePath != widget.entry.cloudImagePath) {
      _downloadTriggered = false;
      _imageSourceFuture = _getImageSource();
    }
  }

  /// CP: Get the image source - either local path or cloud download URL.
  /// Returns a record with either localPath or downloadUrl set.
  /// Also triggers background download for cloud-only images (Issue #46).
  Future<({String? localPath, String? downloadUrl})> _getImageSource() async {
    final imageService = GetIt.instance<ImageStorageService>();
    final syncService = GetIt.instance<ImageStorageSyncService>();

    // CP: Try local path first
    if (widget.entry.imagePath != null) {
      final fullPath = await imageService.getFullPath(widget.entry.imagePath!);
      if (fullPath != null) {
        final file = File(fullPath);
        if (await file.exists()) {
          return (localPath: fullPath, downloadUrl: null);
        }
      }
    }

    // CP: Fall back to cloud download URL
    if (widget.entry.cloudImagePath != null) {
      // CP: Trigger background download to cache locally (Issue #46)
      if (!_downloadTriggered) {
        _triggerBackgroundDownload();
      }

      final downloadUrl = await syncService.getDownloadUrl(widget.entry.cloudImagePath!);
      if (downloadUrl != null) {
        return (localPath: null, downloadUrl: downloadUrl);
      }
    }

    return (localPath: null, downloadUrl: null);
  }

  /// CP: Triggers a background download of the cloud image.
  /// When complete, refreshes the image source to show the local file.
  void _triggerBackgroundDownload() {
    _downloadTriggered = true;
    final repository = GetIt.instance<EntryRepository>();
    repository.ensureImageAvailable(widget.entry).then((localPath) {
      if (localPath != null && mounted) {
        setState(() {
          _imageSourceFuture = _getImageSource();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.categoryColor ?? CategoryColors.getColorForCategory(widget.entry.category);

    return GestureDetector(
      onTap: widget.onTap,
      child: FutureBuilder<({String? localPath, String? downloadUrl})>(
        future: _imageSourceFuture, // CP: Use cached future
        builder: (context, snapshot) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.isSelected
                    ? color.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: widget.isSelected ? 2 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Column(
                children: [
                  // CP: Category color bar at top
                  Container(
                    height: 3,
                    color: color.withValues(alpha: 0.6),
                  ),
                  // CP: Image content area
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image
                        _buildImage(context, snapshot, theme),

                      // Gradient overlay - fades to black at bottom
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.5),
                              Colors.black,
                            ],
                            stops: const [0.0, 0.4, 0.7],
                          ),
                        ),
                      ),

                      // CP: Title and category overlay - white text on dark gradient
                      Positioned(
                        bottom: 8,
                        left: 12,
                        right: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.entry.imageTitle ?? 'Image',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // CP: Category label
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getDisplayName(widget.entry.category).toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 9,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  // CP: Convert internal category name to display name (Misc -> None)
  String _getDisplayName(String categoryName) =>
      categoryName == Category.miscName ? Category.miscDisplayName : categoryName;

  /// CP: Build the image widget based on available source (local or cloud).
  Widget _buildImage(
    BuildContext context,
    AsyncSnapshot<({String? localPath, String? downloadUrl})> snapshot,
    ThemeData theme,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = snapshot.data;
    if (data == null) {
      return Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image),
      );
    }

    // CP: Local file takes priority
    if (data.localPath != null) {
      return Image.file(
        File(data.localPath!),
        fit: BoxFit.cover,
        cacheWidth: 500,
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image),
        ),
      );
    }

    // CP: Fall back to network image from cloud
    if (data.downloadUrl != null) {
      return Image.network(
        data.downloadUrl!,
        fit: BoxFit.cover,
        cacheWidth: 500,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, color: theme.colorScheme.outline),
              const SizedBox(height: 4),
              Text('Offline', style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      );
    }

    // CP: No image available
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_not_supported),
    );
  }
}
