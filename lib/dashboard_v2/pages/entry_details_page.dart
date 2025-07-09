import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/entry_details_keys.dart';
import 'package:myapp/utils/category_colors.dart';

class EntryDetailsPage extends StatelessWidget {
  final Entry entry;
  final Insight? cachedInsight;
  final bool allowCategoryEdit;

  const EntryDetailsPage({
    super.key,
    required this.entry,
    this.cachedInsight,
    this.allowCategoryEdit = true,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EntryDetailsCubit(
        entryRepository: GetIt.instance<EntryRepository>(),
      )..loadEntry(entry, cachedSummaryInsight: cachedInsight),
      child: BlocConsumer<EntryDetailsCubit, EntryDetailsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            key: entryDetailsPageKey,
            appBar: _buildAppBar(context, state),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, EntryDetailsState state) {
    final cubit = context.read<EntryDetailsCubit>();
    final theme = Theme.of(context);
    final entry = state.entry;

    if (entry == null) {
      return AppBar(key: entryDetailsAppBarKey);
    }

    return AppBar(
      key: entryDetailsAppBarKey,
      title: state.isEditing
          ? const Text('Edit Log')
          : Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: CategoryColors.getColorForCategory(entry.category),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(entry.category),
              ],
            ),
      actions: [
        if (!state.isEditing)
          IconButton(
            key: deleteButtonKey,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context, state),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, EntryDetailsState state) {
    if (state.isLoading || state.entry == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final entry = state.entry!;
    final dateFormat = DateFormat('MMMM d, yyyy');
    final timeFormat = DateFormat('h:mm a');
    final categoryColor = CategoryColors.getColorForCategory(entry.category);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Magazine-style header with date and category
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large date header
                Text(
                  dateFormat.format(entry.timestamp).toUpperCase(),
                  key: entryTimestampKey,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                    height: 1,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      timeFormat.format(entry.timestamp),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Category chip
                    ActionChip(
                      avatar: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: categoryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: Text(
                        entry.category,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      backgroundColor: categoryColor.withValues(alpha: 0.15),
                      side: BorderSide.none,
                      onPressed: allowCategoryEdit ? () => _showCategoryBottomSheet(context, state) : null,
                    ),
                    if (entry.isTask) ...[  
                      const SizedBox(width: 8),
                      Checkbox(
                        key: taskCheckboxKey,
                        value: entry.isCompleted,
                        onChanged: state.isEditing
                            ? null
                            : (_) => context.read<EntryDetailsCubit>().toggleTaskCompletion(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Content area
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary insight as pull-quote style
                if (state.summaryInsight != null || state.isRegeneratingInsight)
                  Container(
                    margin: const EdgeInsets.only(bottom: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: categoryColor,
                          width: 4,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!state.isRegeneratingInsight && state.summaryInsight != null) ...[  
                          Text(
                            '"${state.summaryInsight!.content}"',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w300,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI INSIGHT',
                            style: theme.textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ] else
                          const CircularProgressIndicator(),
                      ],
                    ),
                  ),

                // Main content - entry text
                GestureDetector(
                  onTap: state.isEditing ? null : () => context.read<EntryDetailsCubit>().startEditing(),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: state.isEditing
                        ? TextField(
                            key: entryTextFieldKey,
                            controller: context.read<EntryDetailsCubit>().textController,
                            focusNode: context.read<EntryDetailsCubit>().textFocusNode,
                            maxLines: null,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 20,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: categoryColor.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: categoryColor,
                                  width: 2,
                                ),
                              ),
                              contentPadding: const EdgeInsets.all(20),
                              helperText: '${state.editedText?.length ?? 0} characters',
                              helperStyle: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            onChanged: (text) => context.read<EntryDetailsCubit>().updateEditedText(text),
                            onSubmitted: (_) => context.read<EntryDetailsCubit>().saveAndExitEditMode(),
                          )
                        : Container(
                            key: entryTextViewKey,
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText(
                                  entry.text,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontSize: 20,
                                    height: 1.6,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tap to edit',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryBottomSheet(BuildContext context, EntryDetailsState state) {
    if (state.entry == null) return;

    final categories = GetIt.instance<EntryRepository>().currentCategories;
    final currentCategory = state.entry!.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Change Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category.name == currentCategory;
                  final categoryColor = CategoryColors.getColorForCategory(category.name);
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? categoryColor 
                            : categoryColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 18,
                            )
                          : null,
                    ),
                    title: Text(
                      category.name,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: category.description.isNotEmpty
                        ? Text(
                            category.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      if (!isSelected) {
                        context.read<EntryDetailsCubit>().updateCategory(category.name);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, EntryDetailsState state) {
    if (state.entry == null) return;

    final entryPreview = state.entry!.text.length > 50
        ? '${state.entry!.text.substring(0, 50)}...'
        : state.entry!.text;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: deleteConfirmationDialogKey,
        title: const Text('Delete Entry?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This action cannot be undone.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entryPreview,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await context.read<EntryDetailsCubit>().deleteEntry();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}