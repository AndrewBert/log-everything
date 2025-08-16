import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/dashboard_v2/widgets/connecting_line.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/widgets/voice_input/cubit/voice_input_cubit.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:myapp/dialogs/help_dialog.dart';
import 'package:myapp/dialogs/whats_new_dialog.dart';

class DashboardV2Page extends StatefulWidget {
  const DashboardV2Page({super.key});

  @override
  State<DashboardV2Page> createState() => _DashboardV2PageState();
}

class _DashboardV2PageState extends State<DashboardV2Page> {
  final ScrollController _scrollController = ScrollController();
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAppVersion() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (e) {
      // Handle error silently
    }
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
          elevation: 0,
          title: RichText(
            text: TextSpan(
              style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
              children: <TextSpan>[
                TextSpan(
                  text: 'Log',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextSpan(
                  text: ' / Splitter',
                  style: TextStyle(
                    color: Theme.of(context).appBarTheme.titleTextStyle?.color,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (_appVersion.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Center(
                  child: Text(
                    _appVersion,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Help / About',
              onPressed: () => _showHelpDialog(context),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: BlocListener<EntryCubit, EntryState>(
          listenWhen: (prev, current) =>
              current.splitNotification != null && prev.splitNotification != current.splitNotification,
          listener: (context, state) {
            // CC: Show snackbar with undo option when split occurs
            if (state.splitNotification != null && state.undoBatchId != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.splitNotification!),
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      context.read<EntryCubit>().undoSplit();
                    },
                  ),
                ),
              );
              // CC: Clear notification after showing
              context.read<EntryCubit>().clearSplitNotification();
            }
          },
          child: Stack(
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
                            child: SizedBox(height: 8),
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
                                        ? state.getCategoryColor(selectedEntry.category)
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
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                                      child: ConnectingLine(
                                        isVisible: state.currentInsight != null || state.isGeneratingInsight,
                                      ),
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
                                      getCategoryColor: state.getCategoryColor,
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
                          // CC: Todos carousel with conditional spacing
                          SliverToBoxAdapter(
                            child: BlocBuilder<TodoCubit, TodoState>(
                              builder: (context, todoState) {
                                // CP: Only show spacing if there are todos to display
                                final hasTodos =
                                    todoState.activeTodos.isNotEmpty || todoState.completedTodos.isNotEmpty;

                                if (!hasTodos) {
                                  return const SizedBox(height: 24);
                                }

                                return Column(
                                  children: [
                                    const SizedBox(height: 24),
                                    TodosCarousel(
                                      onHeaderTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const TodosPage(),
                                          ),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                );
                              },
                            ),
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
                                      getCategoryColor: state.getCategoryColor,
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
                                            builder: (context) => const AllCategoriesPage(),
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
                            child: SizedBox(height: 8),
                          ),
                          // CC: Grid with date headers
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final items = _buildItemsWithDateHeaders(state.entries);
                                  if (index >= items.length) {
                                    if (state.hasMoreEntries) {
                                      return const Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }

                                  final item = items[index];

                                  // Date header
                                  if (item is String) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                                      child: Text(
                                        item,
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    );
                                  }

                                  // Entry grid row
                                  if (item is Entry) {
                                    // Count entries in current row (check if we're first in a row)
                                    int entriesInCurrentRow = 0;
                                    for (int i = index - 1; i >= 0 && items[i] is Entry; i--) {
                                      entriesInCurrentRow++;
                                    }

                                    // Skip if we're the second entry in a row (already rendered with first)
                                    if (entriesInCurrentRow % 2 == 1) {
                                      return const SizedBox.shrink();
                                    }

                                    // Find next entry for the row
                                    Entry? nextEntry;
                                    if (index + 1 < items.length && items[index + 1] is Entry) {
                                      nextEntry = items[index + 1] as Entry;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: AspectRatio(
                                              aspectRatio: 1,
                                              child: NewspaperEntryCard(
                                                entry: item,
                                                isInGrid: true,
                                                categoryColor: state.getCategoryColor(item.category),
                                                onTap: () {
                                                  _navigateToEntryDetails(context, item, state);
                                                },
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: nextEntry != null
                                                ? AspectRatio(
                                                    aspectRatio: 1,
                                                    child: NewspaperEntryCard(
                                                      entry: nextEntry,
                                                      isInGrid: true,
                                                      categoryColor: state.getCategoryColor(nextEntry.category),
                                                      onTap: () {
                                                        _navigateToEntryDetails(context, nextEntry!, state);
                                                      },
                                                    ),
                                                  )
                                                : const SizedBox.shrink(),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return const SizedBox.shrink();
                                },
                                childCount:
                                    _buildItemsWithDateHeaders(state.entries).length + (state.hasMoreEntries ? 1 : 0),
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
      ),
    );
  }

  void _navigateToEntryDetails(BuildContext context, Entry entry, DashboardV2State state) {
    // CC: Get primary insight using priority system instead of always showing summary
    final comprehensiveInsight = entry.insight;
    final primaryInsight = comprehensiveInsight?.getPrimaryInsight();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EntryDetailsPage(
          entry: entry,
          cachedInsight: primaryInsight,
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return HelpDialog(onShowWhatsNewPressed: () => _showWhatsNewDialog(context));
      },
    );
  }

  Future<void> _showWhatsNewDialog(BuildContext context, [String? version]) async {
    await showDialog(
      context: context,
      builder: (context) => WhatsNewDialog(currentVersion: version ?? _appVersion),
    );
  }

  // CC: Helper method to get date label
  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final entryDate = DateTime(date.year, date.month, date.day);

    if (entryDate == today) {
      return 'TODAY';
    } else if (entryDate == yesterday) {
      return 'YESTERDAY';
    } else {
      return DateFormat('MMMM d, yyyy').format(date).toUpperCase();
    }
  }

  // CC: Helper to build items list with date headers
  List<dynamic> _buildItemsWithDateHeaders(List<Entry> entries) {
    if (entries.isEmpty) return [];

    final items = <dynamic>[];
    String? lastDateLabel;

    for (final entry in entries) {
      final dateLabel = _getDateLabel(entry.timestamp);
      if (dateLabel != lastDateLabel) {
        items.add(dateLabel); // Add date header
        lastDateLabel = dateLabel;
      }
      items.add(entry);
    }

    return items;
  }
}
