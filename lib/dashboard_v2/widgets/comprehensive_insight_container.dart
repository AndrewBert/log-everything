import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class ComprehensiveInsightContainer extends StatelessWidget {
  final ComprehensiveInsight? insight;
  final bool isLoading;
  
  const ComprehensiveInsightContainer({
    super.key,
    this.insight,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AnimatedContainer(
      key: comprehensiveInsightContainerKey,
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoading)
            _buildLoadingState(theme)
          else if (insight != null)
            ..._buildInsightSections(context, insight!),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Analyzing entry...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInsightSections(BuildContext context, ComprehensiveInsight insight) {
    final widgets = <Widget>[];
    
    final summary = insight.getInsightByType(InsightType.summary);
    if (summary != null) {
      widgets.add(_buildSummarySection(context, summary));
      widgets.add(const SizedBox(height: 12));
    }
    
    final emotion = insight.getInsightByType(InsightType.emotion);
    final pattern = insight.getInsightByType(InsightType.pattern);
    
    if (emotion != null || pattern != null) {
      widgets.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (emotion != null) ...[
              Expanded(child: _buildEmotionSection(context, emotion)),
              if (pattern != null) const SizedBox(width: 12),
            ],
            if (pattern != null)
              Expanded(child: _buildPatternSection(context, pattern)),
          ],
        ),
      );
      widgets.add(const SizedBox(height: 12));
    }
    
    final theme = insight.getInsightByType(InsightType.theme);
    if (theme != null) {
      widgets.add(_buildThemeSection(context, theme));
      widgets.add(const SizedBox(height: 12));
    }
    
    final recommendation = insight.getInsightByType(InsightType.recommendation);
    if (recommendation != null) {
      widgets.add(_buildRecommendationSection(context, recommendation));
    }
    
    return widgets;
  }

  Widget _buildSummarySection(BuildContext context, Insight summary) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Summary',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary.content,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmotionSection(BuildContext context, Insight emotion) {
    final theme = Theme.of(context);
    final metadata = emotion.metadata ?? {};
    final secondary = (metadata['secondary'] as List?)?.cast<String>() ?? [];
    final intensity = metadata['intensity'] as String? ?? 'medium';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.emoji_emotions_outlined,
                size: 20,
                color: theme.colorScheme.secondary,
              ),
              const SizedBox(width: 8),
              Text(
                'Emotion',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            emotion.content,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Also: ${secondary.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildIntensityIndicator(context, intensity),
        ],
      ),
    );
  }

  Widget _buildIntensityIndicator(BuildContext context, String intensity) {
    final theme = Theme.of(context);
    final level = intensity == 'high' ? 3 : (intensity == 'medium' ? 2 : 1);
    
    return Row(
      children: List.generate(3, (index) {
        final isActive = index < level;
        return Container(
          width: 24,
          height: 4,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.secondary
                : theme.colorScheme.secondary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildPatternSection(BuildContext context, Insight pattern) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pattern,
                size: 20,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'Pattern',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pattern.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSection(BuildContext context, Insight theme) {
    final themeData = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: themeData.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.category_outlined,
            size: 18,
            color: themeData.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            'Theme: ',
            style: themeData.textTheme.labelMedium?.copyWith(
              color: themeData.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              theme.content,
              style: themeData.textTheme.bodyMedium?.copyWith(
                color: themeData.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationSection(BuildContext context, Insight recommendation) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.1),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Recommendation',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}