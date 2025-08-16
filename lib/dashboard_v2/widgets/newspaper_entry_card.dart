import 'package:flutter/material.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/category_colors.dart';

class NewspaperEntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isInGrid;
  final Color? categoryColor; // CC: Accept color from parent
  final Function(Entry)? onCategoryTap; // CC: Callback for category chip tap

  const NewspaperEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelected = false,
    this.isInGrid = false,
    this.categoryColor,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = this.categoryColor ?? CategoryColors.getColorForCategory(entry.category);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(
          horizontal: isInGrid ? 4 : 2,
          vertical: isInGrid ? 4 : 2,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? categoryColor.withValues(alpha: 0.6)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Minimal category indicator
            Container(
              height: 3,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.6),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Entry text with newspaper-style typography
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate how many lines can fit based on available height
                          final textStyle = theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                          );
                          // Approximate line height: fontSize * height
                          final lineHeight = 15 * 1.4;
                          final maxLines = (constraints.maxHeight / lineHeight).floor();

                          return Text(
                            entry.text,
                            maxLines: maxLines > 0 ? maxLines : 1,
                            overflow: TextOverflow.ellipsis,
                            style: textStyle,
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Bottom metadata row with todo indicator and category
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // CC: Todo indicator on the left
                        if (entry.isTask)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                entry.isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                size: 14,
                                color: entry.isCompleted
                                    ? theme.colorScheme.primary.withValues(alpha: 0.7)
                                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                entry.isCompleted ? 'DONE' : 'TODO',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          )
                        else
                          const SizedBox(), // Empty space when not a task
                        // CC: Category chip on the right
                        GestureDetector(
                          onTap: onCategoryTap != null
                              ? () {
                                  onCategoryTap!(entry);
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: categoryColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  entry.category.toUpperCase(),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontSize: 11,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w600,
                                    color: categoryColor.withValues(alpha: 0.9),
                                  ),
                                ),
                                if (onCategoryTap != null) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 12,
                                    color: categoryColor.withValues(alpha: 0.7),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
