import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../entry/entry.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';
import '../utils/widget_keys.dart';
import 'entry_context_menu.dart';

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
  void _showContextMenu(
    BuildContext context,
    Entry entry,
    Offset globalPosition,
  ) {
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
              position: Offset(
                menuX,
                menuY,
              ), // CP: Use intelligent relative position
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.6),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
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
                final nextItem = (index + 1 < listItems.length) ? listItems[index + 1] : null;
                if (currentItem is Entry && nextItem is Entry) {
                  return const SizedBox(
                    height: 16.0,
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
                  return AnimatedSlideCard(
                    child: _SwipeableEntryCard(
                      entry: entry,
                      onDelete: () => onDeletePressed(entry),
                      child: _EntryCard(
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
      duration: const Duration(
        milliseconds: 200,
      ), // CP: Reduced from 400ms to make it faster
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(
        0.0,
        0.05,
      ), // CP: Much more subtle slide - reduced from 0.3 to 0.05
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

  const _SwipeableEntryCard({
    required this.entry,
    required this.child,
    required this.onDelete,
  });

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
          colors: [
            Colors.red.shade600,
            Colors.orange.shade500,
            Colors.yellow.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        // CP: Subtle glow effect
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
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
                  return Transform.rotate(
                    angle: rotation,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                  );
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
  final Function(Offset) onLongPress;

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
    required this.onLongPress,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> with TickerProviderStateMixin {
  // CP: Random emoji selection for the peeping feature
  static const List<String> _peepingEmojis = [
    '👀',
    '🫣',
    '👻',
    '🤫',
    '🤪',
    '🦄',
  ];
  late final bool _showPeepingEmoji;
  late final String _selectedEmoji;
  late final double _horizontalOffset;

  // CP: Animation controller for highlight effects with longer duration for smoothness
  late AnimationController _highlightController;
  late Animation<double> _highlightOpacity;
  late Animation<double> _highlightScale;
  late Animation<double> _borderOpacity;
  late Animation<double> _glowIntensity;

  // CP: Add mounted state tracking to prevent unsafe ancestor lookups
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // CP: 1% chance to show a peeping emoji (rare easter egg)
    _showPeepingEmoji = (DateTime.now().millisecondsSinceEpoch % 100) < 1;
    _selectedEmoji = _peepingEmojis[DateTime.now().millisecondsSinceEpoch % _peepingEmojis.length];
    _horizontalOffset = 20.0 + (DateTime.now().millisecondsSinceEpoch % 60);

    // CP: Longer duration for smoother animations
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // CP: Staggered animations for more fluid effect
    _highlightOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _highlightController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _highlightScale = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(
        parent: _highlightController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    _borderOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _highlightController,
        curve: const Interval(0.1, 0.8, curve: Curves.easeInOutQuart),
      ),
    );

    _glowIntensity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _highlightController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutExpo),
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _highlightController.dispose();
    super.dispose();
  }

  // CP: Safe method to check if we can animate
  void _safeAnimateHighlight(bool shouldHighlight) {
    if (_isDisposed || !mounted) return;
    
    if (shouldHighlight) {
      _highlightController.forward();
    } else {
      _highlightController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // CP: Check if this entry is currently being edited or has context menu open
    return BlocBuilder<EntryCubit, EntryState>(
      buildWhen:
          (prev, current) =>
              prev.editingEntry != current.editingEntry ||
              prev.isEditingMode != current.isEditingMode ||
              prev.contextMenuEntry != current.contextMenuEntry,
      builder: (context, state) {
        final isBeingEdited = state.isEditingMode && state.editingEntry == widget.entry;
        final hasContextMenuOpen = state.contextMenuEntry == widget.entry;
        final shouldHighlight = isBeingEdited || hasContextMenuOpen;

        // CP: Use safe animation method
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _safeAnimateHighlight(shouldHighlight);
        });

        return AnimatedBuilder(
          animation: _highlightController,
          builder: (context, child) {
            return Transform.scale(
              scale: shouldHighlight ? _highlightScale.value : 1.0,
              child: GestureDetector(
                onLongPressStart: (details) => widget.onLongPress(details.globalPosition),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (_showPeepingEmoji)
                      Positioned(
                        left: _horizontalOffset,
                        top: -15, // CP: Position to peek over the card
                        child: Transform.rotate(
                          angle: -0.2 + (DateTime.now().millisecondsSinceEpoch % 4) * 0.1,
                          child: Text(
                            _selectedEmoji,
                            style: const TextStyle(
                              fontSize: 28,
                              height: 1, // CP: Adjust text height to prevent layout issues
                            ),
                          ),
                        ),
                      ),
                    // CP: Enhanced highlight border overlay with staggered animated effects
                    if (shouldHighlight)
                      Positioned.fill(
                        child: Opacity(
                          opacity: _borderOpacity.value,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: theme.colorScheme.primary,
                                width: 3.0,
                              ),
                              // CP: Animated glow with varying intensity
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.4 * _glowIntensity.value,
                                  ),
                                  blurRadius: 12.0 * _glowIntensity.value,
                                  spreadRadius: 2.0 * _glowIntensity.value,
                                ),
                                BoxShadow(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.2 * _glowIntensity.value,
                                  ),
                                  blurRadius: 20.0 * _glowIntensity.value,
                                  spreadRadius: 4.0 * _glowIntensity.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    // CP: Animated background highlight with smooth opacity transition
                    if (shouldHighlight)
                      Positioned.fill(
                        child: Opacity(
                          opacity: _highlightOpacity.value * 0.08,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    Container(
                      key: entryCardKey(widget.entry, filterContext: context.read<EntryCubit>().state.filterCategory),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          stops: const [0.01, 0.01],
                          colors: [
                            // CP: Keep original colors regardless of highlight state
                            widget.categoryColor.withValues(alpha: 0.8),
                            widget.isNew ? theme.cardColor.withValues(alpha: 0.96) : theme.cardColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color:
                                widget.isNew
                                    ? theme.colorScheme.primary.withValues(
                                      alpha: 0.24,
                                    )
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
                          // CP: Add editing indicator banner at the top
                          if (isBeingEdited)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 6.0,
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(
                                  alpha: 0.9,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12.0),
                                  topRight: Radius.circular(12.0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    size: 16.0,
                                    color: theme.colorScheme.onPrimary,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Editing...',
                                    style: TextStyle(
                                      color: theme.colorScheme.onPrimary,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              14.0,
                              16.0,
                              14.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // CP: Expandable text section
                                _ExpandableText(
                                  text: widget.entry.text,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.4,
                                    // CP: Slightly mute text when being edited to indicate it's in input field
                                    color:
                                        isBeingEdited ? theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7) : null,
                                  ),
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
                                          widget.timeFormatter.format(
                                            widget.entry.timestamp,
                                          ),
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
                                        // CP: Safe category chip with proper lifecycle management
                                        _SafeCategoryChip(
                                          entry: widget.entry,
                                          isProcessing: widget.isProcessing,
                                          categoryColor: widget.categoryColor,
                                          categoryDisplayName: widget.categoryDisplayName,
                                          onPressed: widget.isProcessing 
                                              ? null 
                                              : () {
                                                  HapticFeedback.lightImpact();
                                                  widget.onChangeCategoryPressed(widget.entry);
                                                },
                                        ),
                                        const SizedBox(width: 8.0),
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
                  ],
                ),
              ),
            );
          },
        );
      },
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
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
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

class _SafeCategoryChip extends StatefulWidget {
  final Entry entry;
  final bool isProcessing;
  final Color categoryColor;
  final String Function(String) categoryDisplayName;
  final VoidCallback? onPressed;

  const _SafeCategoryChip({
    required this.entry,
    required this.isProcessing,
    required this.categoryColor,
    required this.categoryDisplayName,
    this.onPressed,
  });

  @override
  State<_SafeCategoryChip> createState() => _SafeCategoryChipState();
}

class _SafeCategoryChipState extends State<_SafeCategoryChip> {
  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _handlePress() {
    if (_isDisposed || !mounted) return;
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    // CP: Use a simple GestureDetector instead of ActionChip to avoid Material widget lifecycle issues
    return GestureDetector(
      onTap: widget.onPressed != null ? _handlePress : null,
      child: Container(
        key: entryCategoryChipKey(widget.entry),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: widget.isProcessing
              ? Colors.orange.shade100.withValues(alpha: 0.8)
              : widget.categoryColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: widget.isProcessing
                ? Colors.orange.withValues(alpha: 0.3)
                : widget.categoryColor.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        child: Text(
          widget.categoryDisplayName(widget.entry.category),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: widget.isProcessing
                ? Colors.orange[900]
                : CategoryColors.getTextColorForCategory(widget.entry.category),
          ),
        ),
      ),
    );
  }
}
