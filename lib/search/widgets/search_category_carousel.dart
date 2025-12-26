import 'package:flutter/material.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:myapp/utils/search_keys.dart';

class SearchCategoryCarousel extends StatelessWidget {
  final List<Category> categories;
  final void Function(Category category) onCategoryTap;

  const SearchCategoryCarousel({
    super.key,
    required this.categories,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      key: searchCategoryCarouselKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'MATCHING CATEGORIES',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isFirst = index == 0;
              final isLast = index == categories.length - 1;
              final categoryColor = category.color ?? CategoryColors.getColorForCategory(category.name);

              return Padding(
                padding: EdgeInsets.only(
                  left: isFirst ? 16 : 4,
                  right: isLast ? 16 : 4,
                ),
                child: _SearchCategoryChip(
                  category: category,
                  color: categoryColor,
                  onTap: () => onCategoryTap(category),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SearchCategoryChip extends StatelessWidget {
  final Category category;
  final Color color;
  final VoidCallback onTap;

  const _SearchCategoryChip({
    required this.category,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: searchCategoryChipKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                category.name.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
