import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/cubit/category_entries_cubit.dart';
import 'package:myapp/dashboard_v2/pages/entry_details_page.dart';
import 'package:myapp/dashboard_v2/pages/edit_category_page.dart';
import 'package:myapp/dashboard_v2/widgets/newspaper_entry_card.dart';
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
                    height: 3,
                    color: categoryColor.withValues(alpha: 0.6),
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
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ABOUT THIS CATEGORY',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              state.category!.description,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 15,
                                height: 1.4,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                              ),
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
                        return NewspaperEntryCard(
                          entry: entry,
                          isInGrid: true,
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
