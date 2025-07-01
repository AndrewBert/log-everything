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

  const EntryDetailsPage({
    super.key,
    required this.entry,
    this.cachedInsight,
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
          ? const Text('Edit Entry')
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
        if (state.isEditing) ...[
          TextButton(
            key: cancelButtonKey,
            onPressed: cubit.cancelEditing,
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          TextButton(
            key: saveButtonKey,
            onPressed: state.isSaving ? null : cubit.saveAndExitEditMode,
            child: state.isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.primary,
                      ),
                    ),
                  )
                : const Text('Save'),
          ),
        ] else ...[
          IconButton(
            key: categoryButtonKey,
            icon: const Icon(Icons.category_outlined),
            onPressed: () => _showCategoryDialog(context, state),
          ),
          IconButton(
            key: deleteButtonKey,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _showDeleteDialog(context, state),
          ),
        ],
      ],
    );
  }

  Widget _buildBody(BuildContext context, EntryDetailsState state) {
    if (state.isLoading || state.entry == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);
    final entry = state.entry!;
    final dateFormat = DateFormat('EEEE, MMMM d, y \'at\' h:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CP: Summary insight
          if (state.summaryInsight != null || state.isRegeneratingInsight)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SimpleInsightContainer(
                key: entrySummaryInsightKey,
                insight: state.summaryInsight,
                isLoading: state.isRegeneratingInsight,
              ),
            ),

          // CP: Timestamp and task checkbox
          Row(
            children: [
              Expanded(
                child: Text(
                  dateFormat.format(entry.timestamp),
                  key: entryTimestampKey,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (entry.isTask)
                Checkbox(
                  key: taskCheckboxKey,
                  value: entry.isCompleted,
                  onChanged: state.isEditing
                      ? null
                      : (_) => context.read<EntryDetailsCubit>().toggleTaskCompletion(),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // CP: Entry text - tappable for editing
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
                        fontSize: 18,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                        contentPadding: const EdgeInsets.all(12),
                        helperText: '${state.editedText?.length ?? 0} characters',
                      ),
                      onChanged: (text) => context.read<EntryDetailsCubit>().updateEditedText(text),
                      onSubmitted: (_) => context.read<EntryDetailsCubit>().saveAndExitEditMode(),
                    )
                  : Container(
                      key: entryTextViewKey,
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.text,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 18,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to edit',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
    );
  }

  void _showCategoryDialog(BuildContext context, EntryDetailsState state) {
    if (state.entry == null) return;

    final categories = GetIt.instance<EntryRepository>().currentCategories;
    final currentCategory = state.entry!.category;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: categorySelectionDialogKey,
        title: const Text('Change Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: categories.map((category) {
              final isSelected = category.name == currentCategory;
              return ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: CategoryColors.getColorForCategory(category.name),
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                ),
                title: Text(category.name),
                subtitle: Text(category.description),
                selected: isSelected,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  if (!isSelected) {
                    context.read<EntryDetailsCubit>().updateCategory(category.name);
                  }
                },
              );
            }).toList(),
          ),
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