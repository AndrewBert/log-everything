import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../entry/entry.dart';
import '../entry/category.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/widget_keys.dart';
import 'entry_context_menu.dart';
import 'entry_card.dart';

class EntriesList extends StatefulWidget {
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

  // Static method to build slivers for use in CustomScrollView
  static List<Widget> buildSlivers({
    required BuildContext context,
    required String Function(DateTime) formatDateHeader,
    required Color Function(String) getCategoryColor,
    required DateFormat timeFormatter,
    required void Function(Entry entry) onChangeCategoryPressed,
    required void Function(Entry entry) onEditPressed,
    required void Function(Entry entry) onDeletePressed,
  }) {
    return [
      _EntriesListSliver(
        formatDateHeader: formatDateHeader,
        getCategoryColor: getCategoryColor,
        timeFormatter: timeFormatter,
        onChangeCategoryPressed: onChangeCategoryPressed,
        onEditPressed: onEditPressed,
        onDeletePressed: onDeletePressed,
      ),
    ];
  }

  @override
  State<EntriesList> createState() => _EntriesListState();
}

// Simple wrapper state that just delegates to sliver implementation
class _EntriesListState extends State<EntriesList> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _EntriesListSliver(
          formatDateHeader: widget.formatDateHeader,
          getCategoryColor: widget.getCategoryColor,
          timeFormatter: widget.timeFormatter,
          onChangeCategoryPressed: widget.onChangeCategoryPressed,
          onEditPressed: widget.onEditPressed,
          onDeletePressed: widget.onDeletePressed,
        ),
      ],
    );
  }
}

// Internal sliver-based widget for entries - contains all the actual implementation
class _EntriesListSliver extends StatefulWidget {
  final String Function(DateTime) formatDateHeader;
  final Color Function(String) getCategoryColor;
  final DateFormat timeFormatter;
  final void Function(Entry entry) onChangeCategoryPressed;
  final void Function(Entry entry) onEditPressed;
  final void Function(Entry entry) onDeletePressed;

  const _EntriesListSliver({
    required this.formatDateHeader,
    required this.getCategoryColor,
    required this.timeFormatter,
    required this.onChangeCategoryPressed,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  @override
  State<_EntriesListSliver> createState() => _EntriesListSliverState();
}

class _EntriesListSliverState extends State<_EntriesListSliver> with TickerProviderStateMixin {
  // CP: Track split entry delays to persist across rebuilds
  final Map<String, Duration> _splitEntryDelays = {};
  final Set<String> _animatedEntries = {};

  // CP: Track split groups for visual grouping
  final Map<String, DateTime> _splitGroups = {}; // timestamp -> when group was created
  final Map<String, AnimationController> _groupControllers = {};
  final Duration _groupDisplayDuration = const Duration(seconds: 4); // How long to show grouping

  // Helper to map backend 'Misc' to frontend 'None' and vice versa
  String categoryDisplayName(String category) => category == 'Misc' ? 'None' : category;

  // CP: Helper to detect if an entry is part of a group of split entries
  int _getSplitEntryIndex(List<dynamic> listItems, int currentIndex, Entry currentEntry) {
    // CP: Look backwards to find other entries with same timestamp (split from same original)
    int splitIndex = 0;
    for (int i = currentIndex - 1; i >= 0; i--) {
      final item = listItems[i];
      if (item is Entry && item.timestamp == currentEntry.timestamp && item.category != 'Processing...') {
        splitIndex++;
      } else if (item is Entry && item.timestamp != currentEntry.timestamp) {
        // CP: Different timestamp, stop looking
        break;
      } else if (item is DateTime) {
        // CP: Hit a date header, stop looking
        break;
      }
    }

    return splitIndex;
  }

  // CP: Generate a unique key for an entry
  String _getEntryKey(Entry entry) {
    return '${entry.timestamp.toIso8601String()}_${entry.text.hashCode}';
  }

  // CP: Check if an entry is part of a split group that should be highlighted
  bool _isInSplitGroup(Entry entry, List<dynamic> listItems) {
    final groupKey = entry.timestamp.toIso8601String();
    if (!_splitGroups.containsKey(groupKey)) return false;

    // CP: Count entries with same timestamp
    int count = 0;
    for (final item in listItems) {
      if (item is Entry && item.timestamp == entry.timestamp && item.category != 'Processing...') {
        count++;
      }
    }

    return count > 1; // Only highlight if there are multiple entries (split)
  }

  // CP: Check and store split entry delays
  void _updateSplitDelays(List<dynamic> listItems) {
    for (int i = 0; i < listItems.length; i++) {
      final item = listItems[i];
      if (item is Entry) {
        final entryKey = _getEntryKey(item);
        final groupKey = item.timestamp.toIso8601String();

        // CP: Only calculate delay if we haven't seen this entry before AND it's new
        if (!_splitEntryDelays.containsKey(entryKey) && !_animatedEntries.contains(entryKey) && item.isNew) {
          int splitIndex = _getSplitEntryIndex(listItems, i, item);
          if (splitIndex > 0) {
            final delay = Duration(milliseconds: splitIndex * 200); // CP: Fast, snappy timing
            _splitEntryDelays[entryKey] = delay;

            // CP: Only create group for NEW split entries (not on app reload)
            if (!_splitGroups.containsKey(groupKey)) {
              _splitGroups[groupKey] = DateTime.now();
              _createGroupController(groupKey);
            }
          }
        }
      }
    }
  }

  // CP: Create animation controller for group highlighting
  void _createGroupController(String groupKey) {
    final controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _groupControllers[groupKey] = controller;

    // CP: Start with fade in, then fade out after delay
    controller.forward().then((_) {
      Future.delayed(_groupDisplayDuration, () {
        if (mounted && _groupControllers.containsKey(groupKey)) {
          controller.reverse().then((_) {
            if (mounted) {
              _cleanupGroup(groupKey);
            }
          });
        }
      });
    });
  }

  // CP: Clean up group resources
  void _cleanupGroup(String groupKey) {
    _groupControllers[groupKey]?.dispose();
    _groupControllers.remove(groupKey);
    _splitGroups.remove(groupKey);
  }

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
            (context, animation, secondaryAnimation) => EntryContextMenu(
              entry: entry,
              position: Offset(menuX, menuY), // CP: Use intelligent relative position
              onEdit: () => widget.onEditPressed(entry),
              onDelete: () => widget.onDeletePressed(entry),
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
            (context, animation, secondaryAnimation) => EntryContextMenu(
              entry: entry,
              position: Offset(menuX, menuY),
              onEdit: () => widget.onEditPressed(entry),
              onDelete: () => widget.onDeletePressed(entry),
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
  void dispose() {
    // CP: Clean up all group controllers
    for (final controller in _groupControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (context, state) {
        // CP: Show empty background when in editing mode
        if (state.isEditingMode) {
          return SliverFillRemaining(
            child: Container(
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
            ),
          );
        }

        final List<dynamic> listItems = state.displayListItems;

        // CP: Update split delays when list changes
        _updateSplitDelays(listItems);

        if (state.isLoading && listItems.isEmpty) {
          return SliverFillRemaining(
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (listItems.isEmpty) {
          return SliverFillRemaining(
            child: AnimatedOpacity(
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
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildListItem(context, listItems, index, state);
              },
              childCount: listItems.length,
            ),
          ),
        );
      },
    );
  }

  Widget _buildListItem(BuildContext context, List<dynamic> listItems, int index, EntryState state) {
    final item = listItems[index];
    final nextItem = (index + 1 < listItems.length) ? listItems[index + 1] : null;

    Widget itemWidget;

    if (item is DateTime) {
      // Enhanced date header styling
      itemWidget = Padding(
        padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        child: Text(
          widget.formatDateHeader(item),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else if (item is Entry) {
      final entry = item;
      final entryKey = _getEntryKey(entry);
      bool isProcessing = entry.category == 'Processing...';
      bool isNew = entry.isNew;
      Color categoryColor = widget.getCategoryColor(entry.category);

      // CP: Get stored delay for this entry (persists across rebuilds)
      Duration? staggerDelay = _splitEntryDelays[entryKey];

      // CP: Check if this entry should be visually grouped
      final inSplitGroup = _isInSplitGroup(entry, listItems);
      final groupKey = entry.timestamp.toIso8601String();
      final groupController = _groupControllers[groupKey];

      Widget entryWidget = AnimatedSlideCard(
        key: ValueKey(entryKey),
        isNew: isNew,
        isProcessing: isProcessing,
        staggerDelay: staggerDelay,
        onAnimationComplete: () {
          // CP: Mark this entry as animated to prevent future delays
          _animatedEntries.add(entryKey);
          _splitEntryDelays.remove(entryKey);
        },
        child: _SwipeableEntryCard(
          entry: entry,
          onDelete: () => widget.onDeletePressed(entry),
          child: BlocBuilder<EntryCubit, EntryState>(
            buildWhen: (prev, current) => prev.categories != current.categories,
            builder: (context, state) {
              // CP: Check if this entry's category is a checklist
              final category = state.categories.firstWhere(
                (cat) => cat.name == entry.category,
                orElse: () => const Category(name: ''),
              );
              final isChecklistCategory = category.isChecklist;

              return EntryCard(
                entry: entry,
                isNew: isNew,
                isProcessing: isProcessing,
                categoryColor: categoryColor,
                timeFormatter: widget.timeFormatter,
                categoryDisplayName: categoryDisplayName,
                onChangeCategoryPressed: widget.onChangeCategoryPressed,
                onEditPressed: widget.onEditPressed,
                onDeletePressed: widget.onDeletePressed,
                onLongPress: (globalPosition) => _showContextMenu(context, entry, globalPosition),
                isChecklistCategory: isChecklistCategory,
                onToggleCompletion:
                    (isChecklistCategory || entry.isTask)
                        ? (entry) => context.read<EntryCubit>().toggleEntryCompletion(entry)
                        : null,
              );
            },
          ),
        ),
      );

      // CP: Wrap with split group highlighting if applicable
      if (inSplitGroup && groupController != null) {
        entryWidget = _SplitGroupWrapper(
          controller: groupController,
          child: entryWidget,
        );
      }

      itemWidget = entryWidget;
    } else {
      itemWidget = Container();
    }

    // Add spacing after items
    Widget spacing = const SizedBox.shrink();
    if (item is Entry && nextItem is Entry) {
      spacing = const SizedBox(height: 16.0); // Increased spacing between entries
    } else if (item is DateTime && nextItem is Entry) {
      spacing = const SizedBox(height: 8.0); // Increased spacing after date header
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        itemWidget,
        spacing,
      ],
    );
  }
}

// CP: Animated card widget for smooth entry animations
class AnimatedSlideCard extends StatefulWidget {
  final Widget child;
  final bool isNew;
  final bool isProcessing;
  final Duration? staggerDelay; // CP: For staggered split animations
  final VoidCallback? onAnimationComplete; // CP: Callback when animation completes

  const AnimatedSlideCard({
    super.key,
    required this.child,
    this.isNew = false,
    this.isProcessing = false,
    this.staggerDelay,
    this.onAnimationComplete,
  });

  @override
  State<AnimatedSlideCard> createState() => _AnimatedSlideCardState();
}

class _AnimatedSlideCardState extends State<AnimatedSlideCard> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // CP: Pulse animation for processing entries
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // CP: Main entrance animation - more dramatic for new entries
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.isNew ? 400 : 200),
      vsync: this,
    );

    // CP: More noticeable slide for new entries
    _slideAnimation = Tween<Offset>(
      begin: Offset(0.0, widget.isNew ? 0.15 : 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: widget.isNew ? Curves.easeOutCubic : Curves.easeOutQuart),
    );

    // CP: Fade in from more transparent for new entries
    _fadeAnimation = Tween<double>(
      begin: widget.isNew ? 0.3 : 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // CP: Scale animation for new entries only - more subtle
    _scaleAnimation = Tween<double>(
      begin: widget.isNew ? 0.92 : 1.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _controller, curve: widget.isNew ? Curves.easeOutCubic : Curves.linear),
    );

    // CP: Pulse animation for processing entries
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.98,
      end: 1.02,
    ).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isProcessing) {
      _pulseController.repeat(reverse: true);
    }

    // CP: Handle staggered delay for split entries
    if (widget.staggerDelay != null) {
      // CP: Start from completely invisible and scaled down for delayed entries
      _controller.value = 0.0;
      Future.delayed(widget.staggerDelay!, () {
        if (mounted) {
          _controller.forward().then((_) {
            if (widget.onAnimationComplete != null) {
              widget.onAnimationComplete!();
            }
          });
        }
      });
    } else {
      // CP: Start animation immediately when widget is created
      _controller.forward().then((_) {
        if (widget.onAnimationComplete != null) {
          widget.onAnimationComplete!();
        }
      });
    }
  }

  @override
  void didUpdateWidget(AnimatedSlideCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CP: Handle processing state changes
    if (widget.isProcessing != oldWidget.isProcessing) {
      if (widget.isProcessing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.animateTo(1.0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _pulseController]),
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value * (widget.isProcessing ? _pulseAnimation.value : 1.0),
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: widget.child,
            ),
          ),
        );
      },
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

// CP: Widget that provides visual grouping for split entries using overlay approach
class _SplitGroupWrapper extends StatelessWidget {
  final AnimationController controller;
  final Widget child;

  const _SplitGroupWrapper({
    required this.controller,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          children: [
            // CP: The actual entry - no changes to its positioning
            this.child,
            // CP: Overlay border that doesn't affect layout
            if (controller.value > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12.0),
                      // CP: Visible outline only, no shadow
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45 * controller.value),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
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