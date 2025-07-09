import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/dashboard_v2/widgets/connecting_line.dart';
import 'package:myapp/dashboard_v2/pages/add_category_page.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class DashboardV2Page extends StatelessWidget {
  const DashboardV2Page({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardV2Cubit(
        entryRepository: GetIt.instance<EntryRepository>(),
      )..loadEntries(),
      child: Scaffold(
        key: dashboardV2PageKey,
        appBar: AppBar(
          key: dashboardV2AppBarKey,
          title: const Text('Dashboard'),
          elevation: 0,
        ),
        body: BlocBuilder<DashboardV2Cubit, DashboardV2State>(
          builder: (context, state) {
            if (state.isLoading && state.entries.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            return CustomScrollView(
              slivers: [
                if (state.entries.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 16),
                  ),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Recent Entries',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 12),
                        BlocBuilder<DashboardV2Cubit, DashboardV2State>(
                          buildWhen: (prev, current) =>
                              prev.currentInsight != current.currentInsight ||
                              prev.isGeneratingInsight != current.isGeneratingInsight,
                          builder: (context, state) {
                            final primaryInsight = state.currentInsight?.getPrimaryInsight();
                            return SimpleInsightContainer(
                              insight: primaryInsight,
                              isLoading: state.isGeneratingInsight,
                              onTap: primaryInsight != null && state.selectedCarouselIndex < state.entries.length
                                  ? () {
                                      final entry = state.entries[state.selectedCarouselIndex];
                                      _navigateToEntryDetails(context, entry, state);
                                    }
                                  : null,
                            );
                          },
                        ),
                        BlocBuilder<DashboardV2Cubit, DashboardV2State>(
                          buildWhen: (prev, current) =>
                              prev.currentInsight != current.currentInsight ||
                              prev.isGeneratingInsight != current.isGeneratingInsight,
                          builder: (context, state) {
                            return ConnectingLine(
                              isVisible: state.currentInsight != null || state.isGeneratingInsight,
                            );
                          },
                        ),
                        BlocBuilder<DashboardV2Cubit, DashboardV2State>(
                          buildWhen: (prev, current) =>
                              prev.selectedCarouselIndex != current.selectedCarouselIndex ||
                              prev.entries != current.entries,
                          builder: (context, state) {
                            return RecentEntriesCarousel(
                              entries: state.entries.take(10).toList(), // CP: Show only recent 10
                              selectedIndex: state.selectedCarouselIndex,
                              onPageChanged: (index) {
                                context.read<DashboardV2Cubit>().selectCarouselEntry(index);
                              },
                              onEntryTap: (entry) {
                                _navigateToEntryDetails(context, entry, state);
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                  // CC: Categories carousel
                  BlocBuilder<DashboardV2Cubit, DashboardV2State>(
                    buildWhen: (prev, current) => prev.entries != current.entries,
                    builder: (context, state) {
                      final categorizedEntries = state.categorizedEntries;
                      if (categorizedEntries.isEmpty) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }

                      return SliverToBoxAdapter(
                        child: Column(
                          children: [
                            CategoriesCarousel(
                              categorizedEntries: categorizedEntries,
                              onCategoryTap: (categoryName, entries) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => CategoryEntriesPage(
                                      categoryName: categoryName,
                                    ),
                                  ),
                                );
                              },
                              onSeeAllTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => AllCategoriesPage(
                                      categorizedEntries: categorizedEntries,
                                      onAddCategory: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const AddCategoryPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'All Entries',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 12),
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
                          if (index >= state.entries.length) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final entry = state.entries[index];
                          return SquareEntryCard(
                            entry: entry,
                            onTap: () {
                              _navigateToEntryDetails(context, entry, state);
                            },
                          );
                        },
                        childCount: state.hasMoreEntries ? state.entries.length + 1 : state.entries.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 24),
                  ),
                ],
                if (state.entries.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No entries yet'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _navigateToEntryDetails(BuildContext context, Entry entry, DashboardV2State state) {
    // CC: Get insight directly from entry
    final comprehensiveInsight = entry.insight;
    final summaryInsight = comprehensiveInsight?.getInsightByType(InsightType.summary);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EntryDetailsPage(
          entry: entry,
          cachedInsight: summaryInsight,
        ),
      ),
    );
  }
}
