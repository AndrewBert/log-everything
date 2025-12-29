import 'package:flutter/material.dart';
import 'package:myapp/entry/category.dart';
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

  // CC: Check if this is a pending/processing entry
  bool get _isPending => entry.category == 'Processing...';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = this.categoryColor ?? CategoryColors.getColorForCategory(entry.category);

    // CC: Wrap in pulsing animation for pending entries
    Widget card = _buildCard(context, theme, categoryColor);

    if (_isPending) {
      return _PulsingCard(child: card);
    }

    return card;
  }

  Widget _buildCard(
    BuildContext context,
    ThemeData theme,
    Color categoryColor,
  ) {
    return GestureDetector(
      onTap: _isPending ? null : onTap,
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

                    // Bottom metadata - vertical stack
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getDisplayName(entry.category).toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
                            entry.isCompleted ? Icons.check_circle : Icons.circle_outlined,
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

  // CP: Convert internal category name to display name (Misc -> None)
  String _getDisplayName(String categoryName) =>
      categoryName == Category.miscName ? Category.miscDisplayName : categoryName;
}

// CC: Animated wrapper that pulses opacity for pending entries
class _PulsingCard extends StatefulWidget {
  final Widget child;

  const _PulsingCard({required this.child});

  @override
  State<_PulsingCard> createState() => _PulsingCardState();
}

class _PulsingCardState extends State<_PulsingCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
