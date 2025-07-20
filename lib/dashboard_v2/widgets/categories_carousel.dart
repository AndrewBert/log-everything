import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/widgets/category_card.dart';
import 'package:myapp/entry/entry.dart';

class CategoriesCarousel extends StatelessWidget {
  final Map<String, List<Entry>> categorizedEntries;
  final Function(String category, List<Entry> entries) onCategoryTap;
  final VoidCallback? onSeeAllTap;

  const CategoriesCarousel({
    super.key,
    required this.categorizedEntries,
    required this.onCategoryTap,
    this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    if (categorizedEntries.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // CC: Same sizing as RecentEntriesCarousel
    final cardWidth = (screenWidth - 48) / 1.9;
    final sortedCategories = categorizedEntries.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length)); // CC: Sort by count

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CC: Tappable header with arrow
        InkWell(
          onTap: onSeeAllTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CATEGORIES',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: cardWidth,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sortedCategories.length,
            itemBuilder: (context, index) {
              final category = sortedCategories[index];
              final isFirst = index == 0;
              final isLast = index == sortedCategories.length - 1;

              return Padding(
                padding: EdgeInsets.only(
                  left: isFirst ? 16 : 8,
                  right: isLast ? 16 : 8,
                ),
                child: SizedBox(
                  width: cardWidth,
                  child: CategoryCard(
                    categoryName: category.key,
                    entryCount: category.value.length,
                    recentEntries: category.value.take(4).toList(),
                    onTap: () => onCategoryTap(category.key, category.value),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}