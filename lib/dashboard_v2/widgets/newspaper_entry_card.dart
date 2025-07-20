import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/category_colors.dart';

class NewspaperEntryCard extends StatelessWidget {
  final Entry entry;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isInGrid;
  final Color? categoryColor; // CC: Accept color from parent

  const NewspaperEntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelected = false,
    this.isInGrid = false,
    this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = this.categoryColor ?? CategoryColors.getColorForCategory(entry.category);
    final dateFormat = DateFormat('MMM d');
    final timeFormat = DateFormat('h:mm a');
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.symmetric(
          horizontal: isInGrid ? 4 : 8,
          vertical: isInGrid ? 4 : 8,
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Entry text with newspaper-style typography
                    Expanded(
                      child: Text(
                        entry.text,
                        maxLines: isInGrid ? 5 : 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.4,
                          fontWeight: FontWeight.w400,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Bottom metadata row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date and time
                        Flexible(
                          flex: 1,
                          child: Text(
                            '${dateFormat.format(entry.timestamp).toUpperCase()} • ${timeFormat.format(entry.timestamp)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        
                        const SizedBox(width: 4),
                        
                        // Category label
                        Flexible(
                          flex: 0,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.3,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              entry.category.toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Task indicator if applicable
                    if (entry.isTask) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            entry.isCompleted
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 14,
                            color: entry.isCompleted
                                ? theme.colorScheme.primary.withValues(alpha: 0.7)
                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.isCompleted ? 'COMPLETED' : 'TODO',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
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