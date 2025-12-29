import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/category_colors.dart';

class RectangularTodoCard extends StatelessWidget {
  final Entry todo;
  final VoidCallback? onTap;
  final VoidCallback? onEntryTap;
  final VoidCallback? onCheckboxTap;
  final bool isAnimatingOut;

  const RectangularTodoCard({
    super.key,
    required this.todo,
    this.onTap,
    this.onEntryTap,
    this.onCheckboxTap,
    this.isAnimatingOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // CC: Get category color from model first, then fallback to CategoryColors
    final categories = GetIt.instance<EntryRepository>().currentCategories;
    final category = categories.firstWhere(
      (cat) => cat.name == todo.category,
      orElse: () => Category(name: todo.category),
    );
    final categoryColor = category.color ?? CategoryColors.getColorForCategory(todo.category);

    return AnimatedOpacity(
      opacity: todo.isCompleted ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onEntryTap ?? onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                children: [
                  // CC: Category color stripe
                  Container(
                    width: 3,
                    color: categoryColor.withValues(alpha: 0.5),
                  ),
                  // CC: Checkbox with expanded touch target
                  InkWell(
                    onTap: onCheckboxTap,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 56,
                      height: 48,
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: todo.isCompleted ? theme.colorScheme.primary : Colors.transparent,
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
                          // CC: Todo text - allow multiple lines for better readability
                          Text(
                            todo.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              decoration: todo.isCompleted ? TextDecoration.lineThrough : null,
                              decorationColor: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // CC: Category label
                          Text(
                            todo.category.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
