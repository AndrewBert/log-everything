import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/pages/category_entries_page.dart';
import 'package:myapp/dashboard_v2/widgets/category_card.dart';
import 'package:myapp/entry/entry.dart';

class AllCategoriesPage extends StatelessWidget {
  final Map<String, List<Entry>> categorizedEntries;

  const AllCategoriesPage({
    super.key,
    required this.categorizedEntries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // CC: Sort categories alphabetically
    final sortedCategories = categorizedEntries.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    // CC: Calculate total entries
    final totalEntries = categorizedEntries.values
        .fold<int>(0, (sum, entries) => sum + entries.length);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Categories'),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // CC: Summary statistics
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${sortedCategories.length} categories, $totalEntries entries',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // CC: Categories grid
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
                  final category = sortedCategories[index];
                  return CategoryCard(
                    categoryName: category.key,
                    entryCount: category.value.length,
                    recentEntries: category.value.take(4).toList(),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => CategoryEntriesPage(
                            categoryName: category.key,
                          ),
                        ),
                      );
                    },
                  );
                },
                childCount: sortedCategories.length,
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