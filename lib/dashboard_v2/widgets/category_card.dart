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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.6)
                  : theme.colorScheme.outline.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CC: Category color indicator
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        categoryColor,
                        categoryColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
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
                                categoryName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: categoryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                entryCount.toString(),
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: categoryColor,
                                  fontWeight: FontWeight.w600,
                                ),
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
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(4),
          child: Text(
            entry.text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 9,
              height: 1.2,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}