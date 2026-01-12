import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/category_colors.dart';

/// Reusable todo card with circular checkbox, category stripe, and clean layout.
/// Used across dashboard, category pages, and todos page.
class TodoCard extends StatefulWidget {
  final Entry todo;
  final VoidCallback? onTap;
  final VoidCallback? onCheckboxTap;
  final bool isHighlighted;

  const TodoCard({
    super.key,
    required this.todo,
    this.onTap,
    this.onCheckboxTap,
    this.isHighlighted = false,
  });

  @override
  State<TodoCard> createState() => _TodoCardState();
}

class _TodoCardState extends State<TodoCard> with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _highlightController, curve: Curves.easeInOut),
    );

    if (widget.isHighlighted) {
      _highlightController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TodoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _highlightController.repeat(reverse: true);
    } else if (!widget.isHighlighted && oldWidget.isHighlighted) {
      _highlightController.stop();
      _highlightController.reset();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = GetIt.instance<EntryRepository>().currentCategories;
    final category = categories.firstWhere(
      (cat) => cat.name == widget.todo.category,
      orElse: () => Category(name: widget.todo.category),
    );
    final categoryColor = category.color ?? CategoryColors.getColorForCategory(widget.todo.category);

    // CP: Build the card content
    Widget cardContent = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
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
                  padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // CP: Circular checkbox with expanded tap target (48x48 per Material guidelines)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onCheckboxTap,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.todo.isCompleted ? theme.colorScheme.primary : Colors.transparent,
                              border: Border.all(
                                color: widget.todo.isCompleted
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: widget.todo.isCompleted
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: theme.colorScheme.onPrimary,
                                  )
                                : null,
                          ),
                        ),
                      ),
                      // CP: Todo text with top padding to align with checkbox
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 12),
                          child: Text(
                            widget.todo.text,
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // CP: Wrap with highlight animation if highlighted
    if (widget.isHighlighted) {
      cardContent = AnimatedBuilder(
        animation: _highlightAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.withValues(alpha: _highlightAnimation.value * 0.8),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: _highlightAnimation.value * 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          );
        },
        child: cardContent,
      );
    }

    return AnimatedOpacity(
      opacity: widget.todo.isCompleted ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: cardContent,
    );
  }
}
