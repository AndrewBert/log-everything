import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../entry/entry.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';
import '../utils/widget_keys.dart';
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
                  return _EntryCard(
                    entry: entry,
                    isNew: isNew,
                    isProcessing: isProcessing,
                    categoryColor: categoryColor,
                    timeFormatter: timeFormatter,
                    categoryDisplayName: categoryDisplayName,
                    onChangeCategoryPressed: onChangeCategoryPressed,
                    onEditPressed: onEditPressed,
                    onDeletePressed: onDeletePressed,
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
}

// CP: Extracted to a separate stateful widget to maintain expansion state properly
class _EntryCard extends StatefulWidget {
  final Entry entry;
  final bool isNew;
  final bool isProcessing;
  final Color categoryColor;
  final DateFormat timeFormatter;
  final String Function(String) categoryDisplayName;
  final Function(Entry) onChangeCategoryPressed;
  final Function(Entry) onEditPressed;
  final Function(Entry) onDeletePressed;

  const _EntryCard({
    required this.entry,
    required this.isNew,
    required this.isProcessing,
    required this.categoryColor,
    required this.timeFormatter,
    required this.categoryDisplayName,
    required this.onChangeCategoryPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: entryCardKey(widget.entry),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          stops: const [0.01, 0.01],
          colors: [
            widget.categoryColor.withValues(alpha: 0.8),
            widget.isNew
                ? theme.cardColor.withValues(alpha: 0.96)
                : theme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color:
                widget.isNew
                    ? theme.colorScheme.primary.withValues(alpha: 0.24)
                    : Colors.black.withValues(alpha: 0.04),
            blurRadius: widget.isNew ? 8.0 : 4.0,
            spreadRadius: widget.isNew ? 1.0 : 0.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CP: Expandable text section
                _ExpandableText(
                  text: widget.entry.text,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                  maxLines: 3,
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
                          widget.timeFormatter.format(widget.entry.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // Row for category chip and action buttons
                    Row(
                      children: [
                        // Category chip without icon/avatar
                        ActionChip(
                          key: entryCategoryChipKey(widget.entry),
                          label: Text(
                            widget.categoryDisplayName(widget.entry.category),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color:
                                  widget.isProcessing
                                      ? Colors.orange[900]
                                      : CategoryColors.getTextColorForCategory(
                                        widget.entry.category,
                                      ),
                            ),
                          ),
                          backgroundColor:
                              widget.isProcessing
                                  ? Colors.orange.shade100.withValues(
                                    alpha: 0.8,
                                  )
                                  : widget.categoryColor.withValues(alpha: 0.2),
                          side: BorderSide.none,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onPressed:
                              widget.isProcessing
                                  ? null
                                  : () {
                                    HapticFeedback.lightImpact();
                                    widget.onChangeCategoryPressed(
                                      widget.entry,
                                    );
                                  },
                          tooltip:
                              widget.isProcessing ? null : 'Change Category',
                        ),
                        const SizedBox(width: 8.0),
                        EntryActions(
                          key: entryActionsWidgetKey(widget.entry),
                          entry: widget.entry,
                          isProcessing: widget.isProcessing,
                          onEditPressed:
                              () => widget.onEditPressed(widget.entry),
                          onDeletePressed:
                              () => widget.onDeletePressed(widget.entry),
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
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const _ExpandableText({required this.text, this.style, this.maxLines = 3});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _isExpanded = false;
  bool? _hasTextOverflow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (_hasTextOverflow == null) {
          final textSpan = TextSpan(text: widget.text, style: widget.style);
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: ui.TextDirection.ltr,
            maxLines: widget.maxLines,
          )..layout(maxWidth: constraints.maxWidth);

          _hasTextOverflow = textPainter.didExceedMaxLines;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              firstChild: Text(
                widget.text,
                style: widget.style,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: Text(widget.text, style: widget.style),
              crossFadeState:
                  _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
            if (_hasTextOverflow ?? false)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: TextButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 4.0,
                    ), // CP: Increased tap target
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _isExpanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
