import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/dashboard_v2/pages/category_entries_page.dart';
import 'package:myapp/dashboard_v2/widgets/category_card.dart';
import 'package:myapp/dashboard_v2/cubit/dashboard_v2_cubit.dart';
import 'package:myapp/search/widgets/search_overlay.dart';
import 'package:myapp/utils/search_keys.dart';

class ArchivedCategoriesPage extends StatefulWidget {
  const ArchivedCategoriesPage({super.key});

  @override
  State<ArchivedCategoriesPage> createState() => _ArchivedCategoriesPageState();
}

class _ArchivedCategoriesPageState extends State<ArchivedCategoriesPage> {
  bool _isSearchOpen = false;

  void _openSearch() {
    setState(() {
      _isSearchOpen = true;
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearchOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardV2Cubit, DashboardV2State>(
        builder: (context, state) {
          final theme = Theme.of(context);

          // CP: Use archived categories from state
          final archivedCategories = state.archivedCategorizedEntries.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          // CP: Calculate total entries in archived categories
          final totalEntries = archivedCategories.fold<int>(
            0,
            (sum, entry) => sum + entry.value.length,
          );

          return Scaffold(
            appBar: AppBar(
              title: const Text('Archived Categories'),
              elevation: 0,
              actions: [
                IconButton(
                  key: archivedCategoriesSearchButtonKey,
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                  tooltip: 'Search Categories',
                ),
              ],
            ),
            body: Stack(
              children: [
                archivedCategories.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.archive_outlined,
                                size: 80,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Archived Categories',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Categories you archive will appear here',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          // CP: Summary statistics
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                '${archivedCategories.length} archived, $totalEntries entries',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // CP: Archived categories grid
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
                                  final category = archivedCategories[index];
                                  return CategoryCard(
                                    categoryName: category.key,
                                    entryCount: category.value.length,
                                    recentEntries: category.value.take(4).toList(),
                                    categoryColor: state.getCategoryColor(category.key),
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
                                childCount: archivedCategories.length,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),
                        ],
                      ),
                if (_isSearchOpen)
                  SearchOverlay.archivedCategoriesOnly(
                    onClose: _closeSearch,
                  ),
              ],
            ),
          );
        },
      );
  }
}
