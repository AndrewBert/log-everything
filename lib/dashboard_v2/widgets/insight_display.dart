import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class InsightDisplay extends StatelessWidget {
  final Insight? insight;
  final bool isLoading;
  final VoidCallback? onTap;
  final Color categoryColor;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final bool useVariableHeight;

  const InsightDisplay({
    super.key,
    this.insight,
    this.isLoading = false,
    this.onTap,
    required this.categoryColor,
    this.margin,
    this.padding,
    this.useVariableHeight = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        key: aiInsightContainerKey,
        duration: const Duration(milliseconds: 300),
        constraints: useVariableHeight
            ? const BoxConstraints(
                minHeight: 160, // Maintain minimum height for visual consistency
              )
            : null,
        height: useVariableHeight ? null : 160,
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
        padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? SizedBox(
                  height: useVariableHeight ? 128 : null, // 160 - 32 (vertical padding)
                  child: _TypewriterLoader(
                    key: const ValueKey('loading'),
                    categoryColor: categoryColor,
                    useVariableHeight: useVariableHeight,
                  ),
                )
              : insight != null
              ? _buildInsightContent(theme)
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }

  Widget _buildInsightContent(ThemeData theme) {
    final content = Row(
      key: ValueKey('insight_${insight!.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: useVariableHeight ? null : double.infinity,
          decoration: BoxDecoration(
            color: categoryColor,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"${insight!.content}"',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w300,
                  height: 1.4,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                ),
                maxLines: useVariableHeight ? null : 4,
                overflow: useVariableHeight ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                _getInsightLabel(insight!.type),
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // Only wrap with IntrinsicHeight when using variable height
    // This allows the border to stretch to match content height
    return useVariableHeight ? IntrinsicHeight(child: content) : content;
  }

  String _getInsightLabel(InsightType type) {
    switch (type) {
      case InsightType.summary:
        return 'SUMMARY';
      case InsightType.emotion:
        return 'EMOTIONAL INSIGHT';
      case InsightType.pattern:
        return 'PATTERN DETECTED';
      case InsightType.theme:
        return 'KEY THEME';
      case InsightType.recommendation:
        return 'RECOMMENDATION';
    }
  }
}

// Typewriter Loading Animation Widget
class _TypewriterLoader extends StatefulWidget {
  final Color categoryColor;
  final bool useVariableHeight;

  const _TypewriterLoader({
    super.key,
    required this.categoryColor,
    this.useVariableHeight = false,
  });

  @override
  State<_TypewriterLoader> createState() => _TypewriterLoaderState();
}

class _TypewriterLoaderState extends State<_TypewriterLoader> with TickerProviderStateMixin {
  late AnimationController _typeController;
  late AnimationController _cursorController;
  late Animation<int> _charAnimation;
  late Animation<double> _cursorOpacity;
  late Animation<double> _progressAnimation;

  final String _loadingText = "Analyzing entry...";

  @override
  void initState() {
    super.initState();

    _typeController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _cursorController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _charAnimation =
        IntTween(
          begin: 0,
          end: _loadingText.length,
        ).animate(
          CurvedAnimation(
            parent: _typeController,
            curve: const Interval(
              0.0,
              0.7,
              curve: Curves.easeOut,
            ),
          ),
        );

    _progressAnimation =
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: _typeController,
            curve: Curves.linear,
          ),
        );

    _cursorOpacity =
        Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).animate(
          CurvedAnimation(
            parent: _cursorController,
            curve: Curves.easeInOut,
          ),
        );

    _typeController.repeat();
    _cursorController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _typeController.dispose();
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([_typeController, _cursorController]),
      builder: (context, child) {
        final displayText = _loadingText.substring(0, _charAnimation.value);
        final isTypingComplete = _charAnimation.value == _loadingText.length;
        final showCursor = !isTypingComplete || _typeController.value > 0.8;

        final content = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: widget.useVariableHeight ? double.infinity : null,
              decoration: BoxDecoration(
                color: widget.categoryColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w300,
                        height: 1.4,
                        fontSize: 18,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      children: [
                        TextSpan(text: displayText),
                        if (showCursor)
                          TextSpan(
                            text: '|',
                            style: TextStyle(
                              color: widget.categoryColor.withValues(
                                alpha: isTypingComplete ? _cursorOpacity.value : 1.0,
                              ),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(1),
                    child: SizedBox(
                      height: 2,
                      width: 120,
                      child: LinearProgressIndicator(
                        value: _progressAnimation.value,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.categoryColor.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        // Wrap with IntrinsicHeight when using variable height to solve infinite height constraint
        return widget.useVariableHeight ? IntrinsicHeight(child: content) : content;
      },
    );
  }
}
