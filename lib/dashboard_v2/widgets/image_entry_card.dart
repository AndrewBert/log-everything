import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/services/image_storage_service.dart';

class ImageEntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final bool isSelected;

  const ImageEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: FutureBuilder<String>(
        future: GetIt.instance<ImageStorageService>().getFullPath(entry.imagePath!),
        builder: (context, snapshot) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background image
                if (snapshot.hasData)
                  Image.file(
                    File(snapshot.data!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image),
                    ),
                  )
                else
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(child: CircularProgressIndicator()),
                  ),

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

                // Title overlay - white text on dark gradient
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: Text(
                    entry.imageTitle ?? 'Image',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
