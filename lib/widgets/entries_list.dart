import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../entry/entry.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';
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
            return Center(
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
            );
          }

          return ListView.separated(
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
                  (index + 1 < listItems.length) ? listItems[index + 1] : null;
              if (currentItem is Entry && nextItem is Entry) {
                return const SizedBox(height: 8.0);
              }
              if (currentItem is DateTime && nextItem is Entry) {
                return const SizedBox(height: 4.0);
              }
              return const SizedBox.shrink();
            },
            itemBuilder: (context, index) {
              final item = listItems[index];

              if (item is DateTime) {
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
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
                // todo pull out into private widget
                return Card(
                  elevation: isNew ? 4.0 : 1.0,
                  margin: const EdgeInsets.symmetric(
                    vertical: 4.0,
                    horizontal: 0,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side:
                        isNew
                            ? BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            )
                            : BorderSide.none,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                    child: ListTile(
                      title: Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Text(entry.text),
                      ),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            timeFormatter.format(entry.timestamp),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          ActionChip(
                            label: Text(
                              entry.category,
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
                                    // Replace deprecated withOpacity
                                    ? Colors.orange.shade100.withAlpha(
                                      (255 * 0.8).round(),
                                    )
                                    : categoryColor.withAlpha(
                                      (255 * 0.2).round(),
                                    ),
                            side: BorderSide.none,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6.0,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onPressed:
                                isProcessing
                                    ? null
                                    : () {
                                      HapticFeedback.lightImpact();
                                      onChangeCategoryPressed(entry);
                                    },
                            tooltip: isProcessing ? null : 'Change Category',
                          ),
                        ],
                      ),
                      trailing: EntryActions(
                        entry: entry,
                        isProcessing: isProcessing,
                        onEditPressed: () => onEditPressed(entry),
                        onDeletePressed: () => onDeletePressed(entry),
                      ),
                      dense: true,
                    ),
                  ),
                );
              }
              return Container();
            },
          );
        },
      ),
    );
  }
}
