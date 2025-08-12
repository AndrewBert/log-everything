import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/pages/category_entries_page.dart';
import 'package:myapp/dashboard_v2/pages/add_category_page.dart';
import 'package:myapp/dashboard_v2/widgets/category_card.dart';
import 'package:myapp/dashboard_v2/cubit/dashboard_v2_cubit.dart';
import 'package:myapp/entry/repository/entry_repository.dart';

class AllCategoriesPage extends StatelessWidget {
  const AllCategoriesPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardV2Cubit(
        entryRepository: GetIt.instance<EntryRepository>(),
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
              elevation: 0,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.add),
                    iconSize: 32,
                    onPressed: () async {
                      // CC: Navigate to add category page and reload on return
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const AddCategoryPage(),
                        ),
                      );
                      if (context.mounted) {
                        context.read<DashboardV2Cubit>().loadEntries();
                      }
                    },
                    tooltip: 'Add Category',
                  ),
                ),
              ],
            ),
            body: sortedCategories.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_outlined,
                            size: 80,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Categories Yet',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Create your first category to organize your entries',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          FilledButton.icon(
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const AddCategoryPage(),
                                ),
                              );
                              if (context.mounted) {
                                context.read<DashboardV2Cubit>().loadEntries();
                              }
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Category'),
                          ),
                        ],
                      ),
                    ),
                  )
                : CustomScrollView(
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
        },
      ),
    );
  }
}
