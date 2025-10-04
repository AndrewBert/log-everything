import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/intl.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';
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

  // CC: Helper method to get category color with proper fallback
  Color _getCategoryColor(String categoryName) {
    final categories = GetIt.instance<EntryRepository>().currentCategories;
    final category = categories.firstWhere(
      (cat) => cat.name == categoryName,
      orElse: () => Category(name: categoryName),
    );
    return category.color ?? CategoryColors.getColorForCategory(categoryName);
  }

  // CC: Helper method to get color for a Category object
  Color _getCategoryColorForCategory(Category category) {
    return category.color ?? CategoryColors.getColorForCategory(category.name);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => EntryDetailsCubit(
        entryRepository: GetIt.instance<EntryRepository>(),
      )..loadEntry(entry, cachedInsight: cachedInsight),
      child: BlocConsumer<EntryDetailsCubit, EntryDetailsState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
        },
        builder: (context, state) {
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, result) async {
              print('[EntryDetailsPage] PopScope onPopInvokedWithResult - didPop: $didPop, isEditing: ${state.isEditing}');
              if (didPop && state.isEditing) {
                print('[EntryDetailsPage] Calling finalizeEdit from PopScope');
                await context.read<EntryDetailsCubit>().finalizeEdit();
              }
            },
            child: Scaffold(
              key: entryDetailsPageKey,
              appBar: _buildAppBar(context, state),
              body: _buildBody(context, state),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, EntryDetailsState state) {
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
                    color: _getCategoryColor(entry.category),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(entry.category),
              ],
            ),
      actions: [
        if (!state.isEditing)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteDialog(context, state);
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete Entry',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    // CC: Get category color with proper fallback to avoid sync issues
    final categoryColor = _getCategoryColor(entry.category);

    return GestureDetector(
      onTap: () {
        // Exit edit mode and save when tapping outside
        if (state.isEditing) {
          context.read<EntryDetailsCubit>().saveAndExitEditMode();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AI Insight with refined visual design
            // Check both cubit state AND entry's persistent flag
            if (state.primaryInsight != null || state.isRegeneratingInsight || (state.entry?.isGeneratingInsight ?? false))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InsightDisplay(
                  insight: state.primaryInsight,
                  isLoading: state.isRegeneratingInsight || (state.entry?.isGeneratingInsight ?? false),
                  categoryColor: categoryColor,
                  margin: EdgeInsets.zero,
                  padding: const EdgeInsets.only(bottom: 8),
                  useVariableHeight: true,
                ),
              ),

            // Main content - entry text
            GestureDetector(
              onTap: state.isEditing
                  ? () {} // Consume tap when editing to prevent parent GestureDetector from triggering
                  : () => context.read<EntryDetailsCubit>().startEditing(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.isEditing
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: categoryColor,
                            width: 2,
                          ),
                        ),
                        child: TextField(
                          key: entryTextFieldKey,
                          controller: context.read<EntryDetailsCubit>().textController,
                          focusNode: context.read<EntryDetailsCubit>().textFocusNode,
                          maxLines: null,
                          textInputAction: TextInputAction.newline,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 18,
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                            helperText: '${state.editedText?.length ?? 0} characters',
                            helperStyle: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          onChanged: (text) => context.read<EntryDetailsCubit>().updateEditedText(text),
                        ),
                      )
                    : Container(
                        key: entryTextViewKey,
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.text,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.edit_outlined,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Tap to edit',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                // Copy button
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      await Clipboard.setData(ClipboardData(text: entry.text));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Copied to clipboard'),
                                            duration: const Duration(seconds: 2),
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.copy_outlined,
                                            size: 16,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Copy',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 40),

            // Magazine-style date and metadata section (at the very bottom)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
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
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeFormat.format(entry.timestamp),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      // Save status indicator
                      if (state.saveStatus != SaveStatus.idle)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (state.saveStatus == SaveStatus.saving)
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            if (state.saveStatus == SaveStatus.saved)
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: theme.colorScheme.primary,
                              ),
                            const SizedBox(width: 4),
                            Text(
                              state.saveStatus == SaveStatus.saving ? 'Saving...' : 'Saved',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: state.saveStatus == SaveStatus.saving
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.primary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      // Category chip
                      InkWell(
                        onTap: allowCategoryEdit ? () => _showCategoryBottomSheet(context, state) : null,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: categoryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entry.category,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (allowCategoryEdit) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (entry.isTask)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Task',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Checkbox(
                              key: taskCheckboxKey,
                              value: entry.isCompleted,
                              onChanged: state.isEditing
                                  ? null
                                  : (_) => context.read<EntryDetailsCubit>().toggleTaskCompletion(),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryBottomSheet(BuildContext context, EntryDetailsState state) {
    if (state.entry == null) return;

    final categories = GetIt.instance<EntryRepository>().currentCategories;
    final currentCategory = state.entry!.category;
    // CC: Capture the cubit reference before entering the modal sheet context
    final entryDetailsCubit = context.read<EntryDetailsCubit>();

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
        builder: (_, scrollController) => Column(
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
                  final categoryColor = _getCategoryColorForCategory(category);

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isSelected ? categoryColor : categoryColor.withValues(alpha: 0.2),
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
                        entryDetailsCubit.updateCategory(category.name);
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

    final entryPreview = state.entry!.text.length > 50 ? '${state.entry!.text.substring(0, 50)}...' : state.entry!.text;

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
