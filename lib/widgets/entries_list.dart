import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../entry/entry.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/widget_keys.dart';
import 'entry_context_menu.dart';
import 'entry_card.dart';

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
  String categoryDisplayName(String category) => category == 'Misc' ? 'None' : category;

  // CP: Show context menu at a consistent position relative to the entry card
  void _showContextMenu(BuildContext context, Entry entry, Offset globalPosition) {
    // CP: Don't show context menu if entry is processing
    if (entry.category == 'Processing...') {
      return;
    }

    // CP: Add more punchy haptic feedback on long press
    HapticFeedback.heavyImpact();

    // CP: Set the context menu entry in the cubit to trigger highlighting
    context.read<EntryCubit>().setContextMenuEntry(entry);

    // CP: Find the entry card widget to get its position and size
    // CP: Pass filter context to prevent GlobalKey duplicates
    final entryState = context.read<EntryCubit>().state;
    final entryKey = entryCardKey(entry, filterContext: entryState.filterCategory);
    final RenderBox? entryBox = entryKey.currentContext?.findRenderObject() as RenderBox?;

    if (entryBox != null) {
      // CP: Get the entry card's position and size
      final entryPosition = entryBox.localToGlobal(Offset.zero);
      final entrySize = entryBox.size;
      final screenSize = MediaQuery.of(context).size;

      // CP: Intelligent positioning based on card location on screen
      final cardCenterY = entryPosition.dy + (entrySize.height / 2);
      final isInBottomHalf = cardCenterY > (screenSize.height / 2);

      // CP: Estimate context menu height (3 options + padding + dividers ≈ 140px)
      const estimatedMenuHeight = 140.0;

      // CP: Position menu relative to the card:
      // - Horizontally: always centered to the card
      // - Vertically: well below card if in top half, well above card if in bottom half
      final menuX = entryPosition.dx + (entrySize.width / 2);
      final menuY =
          isInBottomHalf
              ? entryPosition.dy -
                  estimatedMenuHeight -
                  16.0 // CP: Menu height + 16px above the card
              : entryPosition.dy + entrySize.height + 16.0; // CP: 16px below the card

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.transparent, // CP: Completely transparent - no dimming effect
        barrierLabel: 'Entry context menu',
        pageBuilder:
            (context, _, __) => EntryContextMenu(
              entry: entry,
              position: Offset(menuX, menuY), // CP: Use intelligent relative position
              onEdit: () => onEditPressed(entry),
              onDelete: () => onDeletePressed(entry),
              onCopyText: () {
                Clipboard.setData(ClipboardData(text: entry.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Text copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
      ).then((_) {
        // CP: Clear the context menu entry when dialog is dismissed
        if (context.mounted) {
          context.read<EntryCubit>().clearContextMenuEntry();
          // CP: Use focusedChild?.unfocus() for more reliable behavior
          FocusScope.of(context).focusedChild?.unfocus();
        }
      });
    } else {
      // CP: Fallback to original position if card not found
      final screenSize = MediaQuery.of(context).size;
      final menuX = screenSize.width / 2;
      final menuY = screenSize.height * 0.4;

      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        barrierLabel: 'Entry context menu',
        pageBuilder:
            (context, _, __) => EntryContextMenu(
              entry: entry,
              position: Offset(menuX, menuY),
              onEdit: () => onEditPressed(entry),
              onDelete: () => onDeletePressed(entry),
              onCopyText: () {
                Clipboard.setData(ClipboardData(text: entry.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Text copied to clipboard'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
      ).then((_) {
        if (context.mounted) {
          context.read<EntryCubit>().clearContextMenuEntry();
          // CP: Use focusedChild?.unfocus() for more reliable behavior
          FocusScope.of(context).focusedChild?.unfocus();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BlocBuilder<EntryCubit, EntryState>(
        builder: (context, state) {
          // CP: Show empty background when in editing mode
          if (state.isEditingMode) {
            return Container(
              color: Theme.of(context).colorScheme.surface,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Editing Entry',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Make your changes in the input field below',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
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
              padding: const EdgeInsets.only(bottom: 150.0, left: 16.0, right: 16.0, top: 8.0),
              itemCount: listItems.length,
              separatorBuilder: (context, index) {
                final currentItem = listItems[index];
                final nextItem = (index + 1 < listItems.length) ? listItems[index + 1] : null;
                if (currentItem is Entry && nextItem is Entry) {
                  return const SizedBox(height: 16.0); // Increased spacing between entries
                }
                if (currentItem is DateTime && nextItem is Entry) {
                  return const SizedBox(height: 8.0); // Increased spacing after date header
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
                  return AnimatedSlideCard(
                    child: _SwipeableEntryCard(
                      entry: entry,
                      onDelete: () => onDeletePressed(entry),
                      child: EntryCard(
                        entry: entry,
                        isNew: isNew,
                        isProcessing: isProcessing,
                        categoryColor: categoryColor,
                        timeFormatter: timeFormatter,
                        categoryDisplayName: categoryDisplayName,
                        onChangeCategoryPressed: onChangeCategoryPressed,
                        onEditPressed: onEditPressed,
                        onDeletePressed: onDeletePressed,
                        onLongPress: (globalPosition) => _showContextMenu(context, entry, globalPosition),
                      ),
                    ),
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

// CP: Animated card widget for smooth entry animations
class AnimatedSlideCard extends StatefulWidget {
  final Widget child;

  const AnimatedSlideCard({super.key, required this.child});

  @override
  State<AnimatedSlideCard> createState() => _AnimatedSlideCardState();
}

class _AnimatedSlideCardState extends State<AnimatedSlideCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200), // CP: Reduced from 400ms to make it faster
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.05), // CP: Much more subtle slide - reduced from 0.3 to 0.05
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    ); // CP: Changed curve for smoother animation

    _fadeAnimation = Tween<double>(
      begin: 0.7, // CP: Start more visible - changed from 0.0 to 0.7
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // CP: Start animation immediately when widget is created
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(opacity: _fadeAnimation, child: widget.child),
    );
  }
}

// CP: Swipeable wrapper for entry cards with nuke theme
class _SwipeableEntryCard extends StatefulWidget {
  final Entry entry;
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeableEntryCard({required this.entry, required this.child, required this.onDelete});

  @override
  State<_SwipeableEntryCard> createState() => _SwipeableEntryCardState();
}

class _SwipeableEntryCardState extends State<_SwipeableEntryCard> {
  // CP: Fun nuke-themed emojis for different swipe directions
  static const List<String> _leftNukeEmojis = ['💥', '🧨', '💣', '🔥', '⚡', '🌪️'];
  static const List<String> _rightNukeEmojis = ['☢️', '💀', '💥', '🌋', '⚡', '🔥'];

  late final String _leftEmoji;
  late final String _rightEmoji;

  @override
  void initState() {
    super.initState();
    // CP: Select random emojis for this specific entry card
    final random = DateTime.now().millisecondsSinceEpoch + widget.entry.text.hashCode;
    _leftEmoji = _leftNukeEmojis[random % _leftNukeEmojis.length];
    _rightEmoji = _rightNukeEmojis[(random * 7) % _rightNukeEmojis.length];
  }

  @override
  Widget build(BuildContext context) {
    // CP: Don't allow swiping processing entries
    if (widget.entry.category == 'Processing...') {
      return widget.child;
    }

    return Dismissible(
      // CP: Use the consistent key from widget_keys.dart
      key: ValueKey('dismissible_${widget.entry.timestamp.toIso8601String()}_${widget.entry.text.hashCode}'),
      direction: DismissDirection.horizontal, // CP: Allow both directions
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3, // CP: Lower threshold for easier dismissal
        DismissDirection.endToStart: 0.3,
      },
      // CP: Custom background with nuke theme
      background: _buildNukeBackground(isLeftSwipe: true),
      secondaryBackground: _buildNukeBackground(isLeftSwipe: false),
      onDismissed: (direction) {
        // CP: Immediate deletion with dramatic effects - no confirmation needed!
        HapticFeedback.heavyImpact(); // CP: Strong feedback for destruction
        widget.onDelete();
      },
      child: widget.child,
    );
  }

  Widget _buildNukeBackground({required bool isLeftSwipe}) {
    final emoji = isLeftSwipe ? _leftEmoji : _rightEmoji;
    final alignment = isLeftSwipe ? Alignment.centerLeft : Alignment.centerRight;
    final padding = isLeftSwipe ? const EdgeInsets.only(left: 20) : const EdgeInsets.only(right: 20);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8), // CP: Match card margins
      decoration: BoxDecoration(
        // CP: Dramatic gradient based on swipe direction
        gradient: LinearGradient(
          begin: isLeftSwipe ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeftSwipe ? Alignment.centerRight : Alignment.centerLeft,
          colors: [Colors.red.shade600, Colors.orange.shade500, Colors.yellow.shade400],
        ),
        borderRadius: BorderRadius.circular(12),
        // CP: Subtle glow effect
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)],
      ),
      child: Padding(
        padding: padding,
        child: Align(
          alignment: alignment,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // CP: Large emoji with rotation animation based on swipe direction
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 300),
                tween: Tween(begin: 0, end: isLeftSwipe ? 0.1 : -0.1),
                builder: (context, rotation, child) {
                  return Transform.rotate(angle: rotation, child: Text(emoji, style: const TextStyle(fontSize: 32)));
                },
              ),
              const SizedBox(height: 4),
              // CP: Action text
              Text(
                isLeftSwipe ? 'NUKE!' : 'DESTROY!',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

