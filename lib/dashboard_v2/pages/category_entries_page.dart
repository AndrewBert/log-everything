import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/cubit/category_entries_cubit.dart';
import 'package:myapp/dashboard_v2/pages/entry_details_page.dart';
import 'package:myapp/dashboard_v2/pages/edit_category_page.dart';
import 'package:myapp/dashboard_v2/widgets/square_entry_card.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/category_colors.dart';

class CategoryEntriesPage extends StatelessWidget {
  final String categoryName;

  const CategoryEntriesPage({
    super.key,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CategoryEntriesCubit(
        entryRepository: GetIt.instance<EntryRepository>(),
        categoryName: categoryName,
      ),
      child: BlocBuilder<CategoryEntriesCubit, CategoryEntriesState>(
        builder: (context, state) {
          final theme = Theme.of(context);
          final categoryColor = CategoryColors.getColorForCategory(categoryName);
          final cubit = context.read<CategoryEntriesCubit>();

          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(state.category?.name ?? categoryName),
                  Text(
                    '${state.entries.length} ${state.entries.length == 1 ? 'entry' : 'entries'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              elevation: 0,
              backgroundColor: categoryColor.withValues(alpha: 0.1),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    if (state.category != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => BlocProvider.value(
                            value: cubit,
                            child: EditCategoryPage(category: state.category!),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ],
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
                // CC: Category description
                if (state.category?.description != null && state.category!.description.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: categoryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: categoryColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'About this category',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.category!.description,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
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
                        if (state.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final entry = state.entries[index];
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
                      childCount: state.entries.length,
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
