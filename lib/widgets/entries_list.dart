import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../entry/entry.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';
import '../utils/widget_keys.dart'; // Import keys
import 'entry_actions.dart';

class EntriesList extends StatelessWidget {
  final String Function(DateTime) formatDateHeader;
  final Color Function(String) getCategoryColor;
  final DateFormat timeFormatter;
  final void Function(Entry entry) onChangeCategoryPressed;
  final void Function(Entry entry) onEditPressed;
  final void Function(Entry entry) onDeletePressed;

  const EntriesList({
    super.key,
    required this.formatDateHeader,
    required this.getCategoryColor,
    required this.timeFormatter,
    required this.onChangeCategoryPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  // Helper to map backend 'Misc' to frontend 'None' and vice versa
  String categoryDisplayName(String category) =>
      category == 'Misc' ? 'None' : category;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BlocBuilder<EntryCubit, EntryState>(
        builder: (context, state) {
          final List<dynamic> listItems = state.displayListItems;
          if (state.isLoading && listItems.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (listItems.isEmpty) {
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: 1.0,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    state.filterCategory != null
                        ? 'No entries found for category: "${state.filterCategory}"'
                        : 'No entries yet.\nType or use the mic below!',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: ListView.separated(
              key: ValueKey<String>(state.filterCategory ?? 'all'),
              padding: const EdgeInsets.only(
                bottom: 150.0,
                left: 16.0,
                right: 16.0,
                top: 8.0,
              ),
              itemCount: listItems.length,
              separatorBuilder: (context, index) {
                final currentItem = listItems[index];
                final nextItem =
                    (index + 1 < listItems.length)
                        ? listItems[index + 1]
                        : null;
                if (currentItem is Entry && nextItem is Entry) {
                  return const SizedBox(
                    height: 12.0,
                  ); // Increased spacing between entries
                }
                if (currentItem is DateTime && nextItem is Entry) {
                  return const SizedBox(
                    height: 8.0,
                  ); // Increased spacing after date header
                }
                return const SizedBox.shrink();
              },
              itemBuilder: (context, index) {
                final item = listItems[index];

                if (item is DateTime) {
                  // Enhanced date header styling
                  return Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(
                      formatDateHeader(item),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  );
                } else if (item is Entry) {
                  final entry = item;
                  bool isProcessing = entry.category == 'Processing...';
                  bool isNew = entry.isNew;
                  Color categoryColor = getCategoryColor(entry.category);

                  // Enhanced card with better visual design
                  return _buildEntryCard(
                    context,
                    entry,
                    isNew,
                    isProcessing,
                    categoryColor,
                  );
                }
                return Container();
              },
            ),
          );
        },
      ),
    );
  }

  // Extracted entry card widget for better organization and readability
  Widget _buildEntryCard(
    BuildContext context,
    Entry entry,
    bool isNew,
    bool isProcessing,
    Color categoryColor,
  ) {
    final theme = Theme.of(context);

    return Container(
      key: entryCardKey(entry),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          stops: const [
            0.01,
            0.01,
          ], // Reduced from 0.02 to 0.01 for thinner border
          colors: [
            categoryColor.withValues(alpha: 0.8),
            isNew ? theme.cardColor.withValues(alpha: 0.96) : theme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color:
                isNew
                    ? theme.colorScheme.primary.withValues(alpha: 0.24)
                    : Colors.black.withValues(alpha: 0.04),
            blurRadius: isNew ? 8.0 : 4.0,
            spreadRadius: isNew ? 1.0 : 0.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Entry text with improved styling
              Text(
                entry.text,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12.0),
              // Bottom row with timestamp and category
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Timestamp with icon for better visual grouping
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14.0,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        timeFormatter.format(entry.timestamp),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  // Row for category chip and action buttons
                  Row(
                    children: [
                      // Category chip without icon/avatar
                      ActionChip(
                        key: entryCategoryChipKey(entry),
                        label: Text(
                          categoryDisplayName(entry.category),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color:
                                isProcessing
                                    ? Colors.orange[900]
                                    : CategoryColors.getTextColorForCategory(
                                      entry.category,
                                    ),
                          ),
                        ),
                        backgroundColor:
                            isProcessing
                                ? Colors.orange.shade100.withValues(alpha: 0.8)
                                : categoryColor.withValues(alpha: 0.2),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed:
                            isProcessing
                                ? null
                                : () {
                                  HapticFeedback.lightImpact();
                                  onChangeCategoryPressed(entry);
                                },
                        tooltip: isProcessing ? null : 'Change Category',
                      ),
                      const SizedBox(width: 8.0),
                      // Actions buttons moved to the right side
                      EntryActions(
                        key: entryActionsWidgetKey(entry),
                        entry: entry,
                        isProcessing: isProcessing,
                        onEditPressed: () => onEditPressed(entry),
                        onDeletePressed: () => onDeletePressed(entry),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
