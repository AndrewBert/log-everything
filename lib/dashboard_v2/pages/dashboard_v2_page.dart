import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/dashboard_v2/widgets/connecting_line.dart';
import 'package:myapp/dashboard_v2/pages/add_category_page.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';
import 'package:myapp/utils/category_colors.dart';

class DashboardV2Page extends StatefulWidget {
  const DashboardV2Page({super.key});

  @override
  State<DashboardV2Page> createState() => _DashboardV2PageState();
}

class _DashboardV2PageState extends State<DashboardV2Page> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entryRepository = GetIt.instance<EntryRepository>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => DashboardV2Cubit(
            entryRepository: entryRepository,
          )..loadEntries(),
        ),
        BlocProvider(
          create: (context) => TodoCubit(
            entryRepository: entryRepository,
          ),
        ),
        BlocProvider(
          create: (context) => EntryCubit(
            entryRepository: entryRepository,
          ),
        ),
        BlocProvider(
          create: (context) => VoiceInputCubit(
            entryCubit: context.read<EntryCubit>(),
          ),
        ),
      ],
      child: Scaffold(
        key: dashboardV2PageKey,
        appBar: AppBar(
          key: dashboardV2AppBarKey,
          title: const Text('Dashboard'),
          elevation: 0,
        ),
        body: Stack(
          children: [
            BlocBuilder<DashboardV2Cubit, DashboardV2State>(
              builder: (context, state) {
                if (state.isLoading && state.entries.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                return BlocListener<DashboardV2Cubit, DashboardV2State>(
                  listenWhen: (prev, current) =>
                      prev.entries.length < current.entries.length && current.entries.isNotEmpty,
                  listener: (context, state) {
                    // CC: Scroll to top when new entry is added
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (state.entries.isNotEmpty) ...[
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              BlocBuilder<DashboardV2Cubit, DashboardV2State>(
                                buildWhen: (prev, current) =>
                                    prev.currentInsight != current.currentInsight ||
                                    prev.isGeneratingInsight != current.isGeneratingInsight,
                                builder: (context, state) {
                                  final primaryInsight = state.currentInsight?.getPrimaryInsight();
                                  final selectedEntry = state.selectedCarouselIndex < state.entries.length
                                      ? state.entries[state.selectedCarouselIndex]
                                      : null;
                                  final categoryColor = selectedEntry != null
                                      ? CategoryColors.getColorForCategory(selectedEntry.category)
                                      : Theme.of(context).colorScheme.primary;
                                  
                                  return NewspaperInsightContainer(
                                    insight: primaryInsight,
                                    isLoading: state.isGeneratingInsight,
                                    categoryColor: categoryColor,
                                    onTap: primaryInsight != null && selectedEntry != null
                                        ? () => _navigateToEntryDetails(context, selectedEntry, state)
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
                        // CC: Todos carousel
                        SliverToBoxAdapter(
                          child: TodosCarousel(
                            onHeaderTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => const TodosPage(),
                                ),
                              );
                            },
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
                              'ALL ENTRIES',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
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
                                return NewspaperEntryCard(
                                  entry: entry,
                                  isInGrid: true,
                                  onTap: () {
                                    _navigateToEntryDetails(context, entry, state);
                                  },
                                );
                              },
                              childCount: state.hasMoreEntries ? state.entries.length + 1 : state.entries.length,
                            ),
                          ),
                        ),
                        // CC: Add padding at bottom for floating input bar
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 80),
                        ),
                      ],
                      if (state.entries.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text('No entries yet'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            // CC: Floating input bar at the bottom
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: FloatingInputBar(),
              ),
            ),
          ],
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
