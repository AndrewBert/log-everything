import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/search/cubit/search_cubit.dart';
import 'package:myapp/search/widgets/search_category_carousel.dart';
import 'package:myapp/utils/search_keys.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:myapp/entry/category.dart';

class SearchOverlay extends StatelessWidget {
  final VoidCallback onClose;
  final SearchMode mode;
  final String? categoryName;
  final bool archivedOnly;

  const SearchOverlay({
    super.key,
    required this.onClose,
  })  : mode = SearchMode.all,
        categoryName = null,
        archivedOnly = false;

  const SearchOverlay.categoriesOnly({
    super.key,
    required this.onClose,
  })  : mode = SearchMode.categoriesOnly,
        categoryName = null,
        archivedOnly = false;

  const SearchOverlay.archivedCategoriesOnly({
    super.key,
    required this.onClose,
  })  : mode = SearchMode.categoriesOnly,
        categoryName = null,
        archivedOnly = true;

  const SearchOverlay.forCategory({
    super.key,
    required this.onClose,
    required String this.categoryName,
  })  : mode = SearchMode.entriesOnly,
        archivedOnly = false;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SearchCubit(
        entryRepository: GetIt.instance<EntryRepository>(),
        mode: mode,
        categoryFilter: categoryName,
        archivedOnly: archivedOnly,
      ),
      child: _SearchOverlayContent(
        onClose: onClose,
        mode: mode,
        categoryName: categoryName,
      ),
    );
  }
}

class _SearchOverlayContent extends StatefulWidget {
  final VoidCallback onClose;
  final SearchMode mode;
  final String? categoryName;

  const _SearchOverlayContent({
    required this.onClose,
    required this.mode,
    this.categoryName,
  });

  @override
  State<_SearchOverlayContent> createState() => _SearchOverlayContentState();
}

class _SearchOverlayContentState extends State<_SearchOverlayContent> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _getHintText() {
    return switch (widget.mode) {
      SearchMode.categoriesOnly => 'Search categories...',
      SearchMode.entriesOnly => widget.categoryName != null
          ? 'Search in ${widget.categoryName}...'
          : 'Search entries...',
      SearchMode.all => 'Search entries...',
    };
  }

  Color _getCategoryColor(String categoryName) {
    final categories = GetIt.instance<EntryRepository>().currentCategories;
    final category = categories.firstWhere(
      (cat) => cat.name == categoryName,
      orElse: () => Category(name: categoryName),
    );
    return category.color ?? CategoryColors.getColorForCategory(categoryName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: searchOverlayKey,
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(context, theme),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, state) {
                  if (state.isSearching) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (state.showNoResults) {
                    return _buildNoResults(context, theme, state.query);
                  }

                  if (!state.hasQuery) {
                    return _buildEmptyState(context, theme);
                  }

                  return _buildResults(context, state);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      child: TextFieldTapRegion(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              key: searchCloseButtonKey,
              icon: const Icon(Icons.arrow_back),
              onPressed: widget.onClose,
            ),
            Expanded(
              child: TextField(
              key: searchTextFieldKey,
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: _getHintText(),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                suffixIcon: BlocBuilder<SearchCubit, SearchState>(
                  builder: (context, state) {
                    if (state.query.isNotEmpty) {
                      return IconButton(
                        key: searchClearButtonKey,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _textController.clear();
                          context.read<SearchCubit>().clearSearch();
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              onChanged: (value) {
                context.read<SearchCubit>().updateQuery(value);
              },
              onTapOutside: (_) => _focusNode.unfocus(),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Type at least 2 characters to search',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(BuildContext context, ThemeData theme, String query) {
    return Center(
      key: searchNoResultsKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            "No results for '$query'",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(BuildContext context, SearchState state) {
    if (widget.mode == SearchMode.categoriesOnly) {
      return _buildCategoryGrid(context, state);
    }

    final results = state.results;
    final theme = Theme.of(context);
    final showCategories = widget.mode == SearchMode.all && state.hasMatchingCategories;

    // Build grid rows (2 entries per row)
    final List<Widget> gridRows = [];
    for (int i = 0; i < results.length; i += 2) {
      final entry1 = results[i];
      final entry2 = i + 1 < results.length ? results[i + 1] : null;

      gridRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: entry1.imagePath != null
                      ? ImageEntryCard(
                          entry: entry1,
                          categoryColor: _getCategoryColor(entry1.category),
                          onTap: () => _navigateToEntry(context, entry1),
                        )
                      : NewspaperEntryCard(
                          entry: entry1,
                          isInGrid: true,
                          categoryColor: _getCategoryColor(entry1.category),
                          onTap: () => _navigateToEntry(context, entry1),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: entry2 != null
                    ? AspectRatio(
                        aspectRatio: 1,
                        child: entry2.imagePath != null
                            ? ImageEntryCard(
                                entry: entry2,
                                categoryColor: _getCategoryColor(entry2.category),
                                onTap: () => _navigateToEntry(context, entry2),
                              )
                            : NewspaperEntryCard(
                                entry: entry2,
                                isInGrid: true,
                                categoryColor: _getCategoryColor(entry2.category),
                                onTap: () => _navigateToEntry(context, entry2),
                              ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      key: searchResultsListKey,
      padding: const EdgeInsets.all(16),
      children: [
        if (showCategories)
          SearchCategoryCarousel(
            categories: state.matchingCategories,
            onCategoryTap: (category) => _navigateToCategory(context, category),
          ),
        if (state.hasResults)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'NOTES',
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
        ...gridRows,
      ],
    );
  }

  Widget _buildCategoryGrid(BuildContext context, SearchState state) {
    final categories = state.matchingCategories;
    final allEntries = GetIt.instance<EntryRepository>().currentEntries;

    return GridView.builder(
      key: searchResultsListKey,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final categoryEntries = allEntries.where((e) => e.category == category.name).toList();
        return CategoryCard(
          categoryName: category.name,
          entryCount: categoryEntries.length,
          recentEntries: categoryEntries.take(4).toList(),
          categoryColor: category.color ?? CategoryColors.getColorForCategory(category.name),
          onTap: () => _navigateToCategory(context, category),
        );
      },
    );
  }

  void _navigateToCategory(BuildContext context, Category category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryEntriesPage(
          categoryName: category.name,
        ),
      ),
    );
  }

  void _navigateToEntry(BuildContext context, Entry entry) {
    final simpleInsight = entry.getCurrentInsight();
    final primaryInsight = simpleInsight != null
        ? Insight(
            id: entry.id,
            type: InsightType.summary,
            title: 'Insight',
            content: simpleInsight.content,
            generatedAt: simpleInsight.generatedAt,
          )
        : null;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EntryDetailsPage(
          entry: entry,
          cachedInsight: primaryInsight,
        ),
      ),
    );
  }
}
