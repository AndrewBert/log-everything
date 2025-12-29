import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/category_colors.dart';

/// Reusable todo card with circular checkbox, category stripe, and clean layout.
/// Used across dashboard, category pages, and todos page.
class TodoCard extends StatelessWidget {
  final Entry todo;
  final VoidCallback? onTap;
  final VoidCallback? onCheckboxTap;

  const TodoCard({
    super.key,
    required this.todo,
    this.onTap,
    this.onCheckboxTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // CP: Category color stripe at top
                  Container(
                    height: 4,
                    color: categoryColor.withValues(alpha: 0.6),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CP: Circular checkbox
                        GestureDetector(
                          onTap: onCheckboxTap,
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
                        const SizedBox(width: 12),
                        // CP: Todo text
                        Expanded(
                          child: Text(
                            todo.text,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 15,
                              height: 1.4,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
