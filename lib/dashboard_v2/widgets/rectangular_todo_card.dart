import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/category_colors.dart';

class RectangularTodoCard extends StatelessWidget {
  final Entry todo;
  final VoidCallback? onTap;
  final VoidCallback? onCheckboxTap;
  final bool isAnimatingOut;

  const RectangularTodoCard({
    super.key,
    required this.todo,
    this.onTap,
    this.onCheckboxTap,
    this.isAnimatingOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = CategoryColors.getColorForCategory(todo.category ?? 'Uncategorized');
    final dateFormatter = DateFormat('MMM d');

    return AnimatedOpacity(
      opacity: todo.isCompleted ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Row(
                children: [
                  // CC: Category color stripe
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          categoryColor,
                          categoryColor.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // CC: Checkbox
                  InkWell(
                    onTap: onCheckboxTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: todo.isCompleted 
                              ? theme.colorScheme.primary 
                              : Colors.transparent,
                          border: Border.all(
                            color: todo.isCompleted 
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: todo.isCompleted
                            ? Icon(
                                Icons.check,
                                size: 16,
                                color: theme.colorScheme.onPrimary,
                              )
                            : null,
                      ),
                    ),
                  ),
                  // CC: Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CC: Todo text
                          Text(
                            todo.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: todo.isCompleted 
                                  ? TextDecoration.lineThrough 
                                  : null,
                              decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // CC: Category and date
                          Row(
                            children: [
                              // CC: Category chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  todo.category ?? 'Uncategorized',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: categoryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // CC: Date
                              Text(
                                dateFormatter.format(todo.timestamp),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}