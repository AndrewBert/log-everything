import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/cubit/category_entries_cubit.dart';
import 'package:myapp/dashboard_v2/pages/entry_details_page.dart';
import 'package:myapp/dashboard_v2/pages/edit_category_page.dart';
import 'package:myapp/dashboard_v2/widgets/newspaper_entry_card.dart';
import 'package:myapp/dashboard_v2/widgets/image_entry_card.dart';
import 'package:myapp/dashboard_v2/widgets/todo_card.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/search/widgets/search_overlay.dart';
import 'package:myapp/utils/search_keys.dart';

class CategoryEntriesPage extends StatefulWidget {
  final String categoryName;

  const CategoryEntriesPage({
    super.key,
    required this.categoryName,
  });

  @override
  State<CategoryEntriesPage> createState() => _CategoryEntriesPageState();
}

class _CategoryEntriesPageState extends State<CategoryEntriesPage> {
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

  Future<void> _showArchiveDialog(
    BuildContext context,
    Category category,
    CategoryEntriesCubit cubit,
  ) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            category.isArchived ? 'Unarchive Category' : 'Archive Category',
          ),
          content: Text(
            category.isArchived
                ? 'Are you sure you want to unarchive "${category.displayName}"?'
                : 'Are you sure you want to archive "${category.displayName}"? It will be hidden from the main category list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(category.isArchived ? 'Unarchive' : 'Archive'),
            ),
          ],
        );
      },
    );

    if (shouldArchive == true && context.mounted) {
      await cubit.toggleArchive();

      if (context.mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              category.isArchived
                  ? 'Category "${category.displayName}" unarchived'
                  : 'Category "${category.displayName}" archived',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CategoryEntriesCubit(
        entryRepository: GetIt.instance<EntryRepository>(),
        categoryName: widget.categoryName,
      ),
      child: BlocBuilder<CategoryEntriesCubit, CategoryEntriesState>(
        builder: (context, state) {
          final theme = Theme.of(context);
          // CC: Use color from state with fallback
          final categoryColor = state.categoryColor ?? Theme.of(context).colorScheme.primary;
          final cubit = context.read<CategoryEntriesCubit>();

          return Scaffold(
            appBar: AppBar(
              title: Column(
                children: [
                  // CP: Use displayName to show "None" for "Misc" category
                  Text(state.category?.displayName ?? _getDisplayName(widget.categoryName)),
                  Text(
                    '${state.entries.length} ${state.entries.length == 1 ? 'entry' : 'entries'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              centerTitle: true,
              elevation: 0,
              actions: [
                IconButton(
                  key: categoryEntriesSearchButtonKey,
                  icon: const Icon(Icons.search),
                  onPressed: _openSearch,
                  tooltip: 'Search Entries',
                ),
                // CP: Hide menu for Misc category (no editable options)
                if (state.category != null && !state.category!.isMisc)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => BlocProvider.value(
                              value: cubit,
                              child: EditCategoryPage(category: state.category!),
                            ),
                          ),
                        );
                      } else if (value == 'archive') {
                        await _showArchiveDialog(context, state.category!, cubit);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined),
                            SizedBox(width: 12),
                            Text('Edit Category'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'archive',
                        child: Row(
                          children: [
                            Icon(state.category!.isArchived
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined),
                            const SizedBox(width: 12),
                            Text(state.category!.isArchived
                                ? 'Unarchive Category'
                                : 'Archive Category'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: Stack(
              children: [
                state.entries.isEmpty && !state.isLoading
                    ? Column(
                    children: [
                      // CC: Category header with color indicator
                      Container(
                        height: 3,
                        color: categoryColor.withValues(alpha: 0.6),
                      ),
                      // CC: Category description if exists
                      if (state.category?.description != null && state.category!.description.isNotEmpty)
                        Padding(
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
                      // CC: Empty state
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.note_alt_outlined,
                                  size: 80,
                                  color: categoryColor.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'No Entries Yet',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Start adding entries to the "${state.category?.name ?? widget.categoryName}" category',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 32),
                                FilledButton.icon(
                                  onPressed: () {
                                    // CC: Navigate back to main page to add entry
                                    Navigator.of(context).popUntil((route) => route.isFirst);
                                  },
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add First Entry'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: categoryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : CustomScrollView(
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
                      // CP: Todo section (active todos only)
                      if (state.activeTodos.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'TODOS',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 8),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final todo = state.activeTodos[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TodoCard(
                                    todo: todo,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => EntryDetailsPage(entry: todo),
                                        ),
                                      );
                                    },
                                    onCheckboxTap: () async {
                                      try {
                                        final repository = GetIt.instance<EntryRepository>();
                                        final updatedTodo = todo.toggleCompletion();
                                        await repository.updateEntry(todo, updatedTodo);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Failed to update todo')),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                );
                              },
                              childCount: state.activeTodos.length,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 16),
                        ),
                      ],
                      // CP: Entries header (only if there are regular entries)
                      if (state.regularEntries.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'ENTRIES',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      if (state.regularEntries.isNotEmpty)
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 8),
                        ),
                      // CC: Grid of entries (regular entries only)
                      if (state.regularEntries.isNotEmpty)
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

                                final entry = state.regularEntries[index];
                              final onTap = () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EntryDetailsPage(
                                      entry: entry,
                                      cachedInsight: entry.getCurrentInsight() != null
                                          ? Insight(
                                              id: entry.id,
                                              type: InsightType.summary,
                                              title: 'Insight',
                                              content: entry.getCurrentInsight()!.content,
                                              generatedAt: entry.getCurrentInsight()!.generatedAt,
                                            )
                                          : null,
                                    ),
                                  ),
                                );
                              };
                                return entry.imagePath != null
                                    ? ImageEntryCard(
                                        entry: entry,
                                        categoryColor: categoryColor,
                                        onTap: onTap,
                                      )
                                    : NewspaperEntryCard(
                                        entry: entry,
                                        isInGrid: true,
                                        categoryColor: categoryColor,
                                        onTap: onTap,
                                      );
                              },
                              childCount: state.regularEntries.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 24),
                      ),
                    ],
                  ),
                if (_isSearchOpen)
                  SearchOverlay.forCategory(
                    onClose: _closeSearch,
                    categoryName: widget.categoryName,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // CP: Convert internal category name to display name (Misc -> None)
  String _getDisplayName(String categoryName) =>
      categoryName == Category.miscName ? Category.miscDisplayName : categoryName;
}
