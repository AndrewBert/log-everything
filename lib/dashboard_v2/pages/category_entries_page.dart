import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/pages/entry_details_page.dart';
import 'package:myapp/dashboard_v2/widgets/square_entry_card.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/category_colors.dart';

class CategoryEntriesPage extends StatelessWidget {
  final String categoryName;
  final List<Entry> entries;

  const CategoryEntriesPage({
    super.key,
    required this.categoryName,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = CategoryColors.getColorForCategory(categoryName);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName),
            Text(
              '${entries.length} ${entries.length == 1 ? 'entry' : 'entries'}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: categoryColor.withValues(alpha: 0.1),
      ),
      body: CustomScrollView(
        slivers: [
          // CC: Category header with color indicator
          SliverToBoxAdapter(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    categoryColor,
                    categoryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 16),
          ),
          // TODO: Add AI insight container for the entire category
          // - Generate insights about patterns, trends, and summaries for all entries in this category
          // - Could include: most common themes, time patterns, emotional trends, suggestions
          // - Use SimpleInsightContainer or create a new CategoryInsightContainer widget
          // CC: Grid of entries
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = entries[index];
                  return SquareEntryCard(
                    entry: entry,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EntryDetailsPage(
                            entry: entry,
                            cachedInsight: entry.insight?.getInsightByType(InsightType.summary),
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: entries.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }
}