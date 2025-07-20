import 'package:flutter/material.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/category_colors.dart';

class CategoryCard extends StatelessWidget {
  final String categoryName;
  final int entryCount;
  final List<Entry> recentEntries;
  final VoidCallback? onTap;
  final bool isSelected;

  const CategoryCard({
    super.key,
    required this.categoryName,
    required this.entryCount,
    required this.recentEntries,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = CategoryColors.getColorForCategory(categoryName);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? categoryColor.withValues(alpha: 0.5)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CC: Category color indicator
                Container(
                  height: 3,
                  color: categoryColor.withValues(alpha: 0.6),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CC: Category name and count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                categoryName.toUpperCase(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 14,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              entryCount.toString(),
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w300,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // CC: Mini grid preview
                        Expanded(
                          child: _buildMiniGridPreview(theme),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniGridPreview(ThemeData theme) {
    // CC: Show up to 4 recent entries in a 2x2 grid
    final entriesToShow = recentEntries.take(4).toList();
    
    if (entriesToShow.isEmpty) {
      return Center(
        child: Text(
          'No entries yet',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: entriesToShow.length,
      itemBuilder: (context, index) {
        final entry = entriesToShow[index];
        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.all(4),
          child: Text(
            entry.text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9,
              height: 1.2,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}