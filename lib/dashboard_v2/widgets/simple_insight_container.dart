import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/dashboard_v2/widgets/shimmer_loading.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class SimpleInsightContainer extends StatelessWidget {
  final Insight? insight;
  final bool isLoading;
  final VoidCallback? onTap;

  const SimpleInsightContainer({
    super.key,
    this.insight,
    this.isLoading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        key: aiInsightContainerKey,
        duration: const Duration(milliseconds: 300),
        height: insight != null || isLoading ? 160 : 0, // CC: Fixed height doubled
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: insight != null || isLoading ? const EdgeInsets.all(16) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: Align(
                alignment: Alignment.topLeft,
                child: child,
              ),
            );
          },
          child: isLoading
              ? const ShimmerLoading(key: ValueKey('loading'))
              : insight != null
              ? Row(
                  key: ValueKey(insight),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _getIconForType(insight!.type),
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        insight!.content,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 16,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }

  IconData _getIconForType(InsightType type) {
    switch (type) {
      case InsightType.pattern:
        return Icons.insights;
      case InsightType.recommendation:
        return Icons.tips_and_updates;
      case InsightType.summary:
        return Icons.lightbulb_outline;
      case InsightType.emotion:
        return Icons.emoji_emotions_outlined;
      case InsightType.theme:
        return Icons.category_outlined;
    }
  }
}
