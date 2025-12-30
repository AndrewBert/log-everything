import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/pages/category_entries_page.dart';
import 'package:myapp/dashboard_v2/pages/add_category_page.dart';
import 'package:myapp/dashboard_v2/pages/archived_categories_page.dart';
import 'package:myapp/dashboard_v2/widgets/category_card.dart';
import 'package:myapp/dashboard_v2/cubit/dashboard_v2_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/intent_detection/services/intent_detection_service.dart';
import 'package:myapp/search/widgets/search_overlay.dart';
import 'package:myapp/utils/search_keys.dart';

class AllCategoriesPage extends StatefulWidget {
  const AllCategoriesPage({
    super.key,
  });

  @override
  State<AllCategoriesPage> createState() => _AllCategoriesPageState();
}

class _AllCategoriesPageState extends State<AllCategoriesPage> {
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
    return BlocProvider(
      create: (context) => DashboardV2Cubit(
        entryRepository: GetIt.instance<EntryRepository>(),
        intentDetectionService: GetIt.instance<IntentDetectionService>(),
      )..loadEntries(),
      child: BlocBuilder<DashboardV2Cubit, DashboardV2State>(
        builder: (context, state) {
          final theme = Theme.of(context);

          // CC: Use categories from state instead of prop to include empty categories
          final sortedCategories = state.categorizedEntries.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

          // CC: Calculate total entries
          final totalEntries = state.categorizedEntries.values.fold<int>(0, (sum, entries) => sum + entries.length);

          return Scaffold(
            appBar: AppBar(
              title: const Text('All Categories'),
              centerTitle: true,
              elevation: 0,
              actions: [
                IconButton(
                  key: allCategoriesSearchButtonKey,
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                  tooltip: 'Search Categories',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'archived') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ArchivedCategoriesPage(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'archived',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined),
                          SizedBox(width: 12),
                          Text('Archived Categories'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Stack(
              children: [
                CustomScrollView(
                  slivers: [
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
                            if (index == 0) {
                              return _buildAddCategoryCard(context, theme);
                            }
                            final category = sortedCategories[index - 1];
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
                          childCount: sortedCategories.length + 1,
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 24),
                    ),
                  ],
                ),
                if (_isSearchOpen)
                  SearchOverlay.categoriesOnly(
                    onClose: _closeSearch,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddCategoryCard(BuildContext context, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddCategoryPage(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 1,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                'Add Category',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
