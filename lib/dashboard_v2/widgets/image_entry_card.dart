import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/services/image_storage_service.dart';
import 'package:myapp/utils/category_colors.dart';

class ImageEntryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = categoryColor ?? CategoryColors.getColorForCategory(entry.category);

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
                    ? color.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
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
                              entry.imageTitle ?? 'Image',
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
                                entry.category.toUpperCase(),
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
          );
        },
      ),
    );
  }
}
