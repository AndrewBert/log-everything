import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class SimpleInsightContainer extends StatelessWidget {
  final Insight? insight;
  final bool isLoading;
  
  const SimpleInsightContainer({
    super.key,
    this.insight,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedContainer(
      key: aiInsightContainerKey,
      duration: const Duration(milliseconds: 300),
      height: insight != null || isLoading ? null : 0,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: insight != null || isLoading 
          ? const EdgeInsets.all(16) 
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: isLoading
            ? Row(
                key: const ValueKey('loading'),
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating insight...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
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