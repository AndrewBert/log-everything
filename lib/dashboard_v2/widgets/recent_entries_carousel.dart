import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class RecentEntriesCarousel extends StatelessWidget {
  final List<Entry> entries;
  final int selectedIndex;
  final Function(int) onPageChanged;
  final Function(Entry)? onEntryTap;
  final Color? Function(String)? getCategoryColor;

  const RecentEntriesCarousel({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onPageChanged,
    this.onEntryTap,
    this.getCategoryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // CC: Requirements: 2 full cards visible, left-aligned with insight, peeking on sides
    final containerPadding = 12.0;
    final cardGap = 4.0;

    // CC: Calculate card width to fit 2 cards within container
    final availableWidth = screenWidth - (containerPadding * 2);
    final cardWidth = (availableWidth - cardGap) / 2;

    return Container(
      key: recentEntriesCarouselKey,
      height: cardWidth,
      margin: EdgeInsets.symmetric(horizontal: containerPadding),
      child: _ListViewCarousel(
        entries: entries,
        selectedIndex: selectedIndex,
        onPageChanged: onPageChanged,
        onEntryTap: onEntryTap,
        getCategoryColor: getCategoryColor,
        cardWidth: cardWidth,
        cardGap: cardGap,
        containerPadding: containerPadding,
      ),
    );
  }
}

// CC: Custom snap physics for ListView carousel to snap to card positions
class SnapScrollPhysics extends ScrollPhysics {
  final double cardWidth;
  final double cardGap;
  final double startOffset;

  const SnapScrollPhysics({
    super.parent,
    required this.cardWidth,
    required this.cardGap,
    required this.startOffset,
  });

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnapScrollPhysics(
      parent: buildParent(ancestor),
      cardWidth: cardWidth,
      cardGap: cardGap,
      startOffset: startOffset,
    );
  }

  @override
  double get minFlingVelocity => 100.0; // Ultra-light swipe threshold

  @override
  double get maxFlingVelocity => 15000.0; // No speed limits

  @override
  double get dragStartDistanceMotionThreshold => 1.0; // Instant response

  double _getTargetPixels(double position, ScrollMetrics metrics) {
    // CC: Calculate the distance between each snap position
    final snapDistance = cardWidth + cardGap;

    // CC: Find the closest snap position (left-aligned)
    final targetIndex = (position / snapDistance).round();
    final targetPosition = targetIndex * snapDistance;

    // CC: Clamp to valid scroll range
    return targetPosition.clamp(0.0, metrics.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    final tolerance = toleranceFor(position);

    // CC: Calculate snap distance and current position
    final snapDistance = cardWidth + cardGap;
    final currentIndex = (position.pixels / snapDistance).round();

    // CC: Determine target based on scroll direction and position
    int targetIndex;

    if (velocity.abs() < minFlingVelocity) {
      // CC: For slow scrolls, snap to nearest
      targetIndex = (position.pixels / snapDistance).round();
    } else {
      // CC: For swipes, always move exactly one card in swipe direction
      final direction = velocity > 0 ? 1 : -1;
      targetIndex = currentIndex + direction;
    }

    // CC: Clamp to valid range
    final maxIndex = (position.maxScrollExtent / snapDistance).floor();
    targetIndex = targetIndex.clamp(0, maxIndex);
    final targetPosition = targetIndex * snapDistance;

    // CC: Create smooth animation to target
    // Use a softer spring for more relaxed, natural movement
    const customSpring = SpringDescription(
      mass: 0.8, // Moderate weight for smoother motion
      stiffness: 100.0, // Softer snap, more relaxed
      damping: 20.0, // More damping for less bounce
    );

    return ScrollSpringSimulation(
      customSpring,
      position.pixels,
      targetPosition,
      velocity, // Preserve ALL swipe energy
      tolerance: tolerance,
    );
  }
}

class _ListViewCarousel extends StatefulWidget {
  final List<Entry> entries;
  final int selectedIndex;
  final Function(int) onPageChanged;
  final Function(Entry)? onEntryTap;
  final Color? Function(String)? getCategoryColor;
  final double cardWidth;
  final double cardGap;
  final double containerPadding;

  const _ListViewCarousel({
    required this.entries,
    required this.selectedIndex,
    required this.onPageChanged,
    this.onEntryTap,
    this.getCategoryColor,
    required this.cardWidth,
    required this.cardGap,
    required this.containerPadding,
  });

  @override
  State<_ListViewCarousel> createState() => _ListViewCarouselState();
}

class _ListViewCarouselState extends State<_ListViewCarousel> {
  late ScrollController _scrollController;
  int _currentIndex = 0;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.selectedIndex;

    // CC: Calculate initial scroll position for selected index
    final initialOffset = _calculateOffsetForIndex(widget.selectedIndex);
    _scrollController = ScrollController(initialScrollOffset: initialOffset);

    // CC: Listen for scroll events to update current index
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(_ListViewCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CC: Animate to new index when selectedIndex changes externally
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        widget.selectedIndex != _currentIndex &&
        widget.entries.isNotEmpty) {
      if (widget.selectedIndex < widget.entries.length) {
        _scrollToIndex(widget.selectedIndex);
      }
    }

    // CC: Handle entries list changes
    if (widget.entries.length != oldWidget.entries.length) {
      final maxIndex = widget.entries.isEmpty ? 0 : widget.entries.length - 1;
      final newIndex = widget.selectedIndex.clamp(0, maxIndex);
      if (newIndex != _currentIndex) {
        _scrollToIndex(newIndex);
      }
    }
  }

  double _calculateOffsetForIndex(int index) {
    // CC: Each card takes cardWidth + cardGap space
    return index * (widget.cardWidth + widget.cardGap);
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;

    _isScrolling = true;
    _currentIndex = index;

    final targetOffset = _calculateOffsetForIndex(index);
    _scrollController
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        )
        .then((_) {
          _isScrolling = false;
        });
  }

  void _onScrollChanged() {
    if (_isScrolling || !_scrollController.hasClients) return;

    // CC: Calculate current index based on scroll position
    final offset = _scrollController.position.pixels;
    final cardStep = widget.cardWidth + widget.cardGap;
    final newIndex = (offset / cardStep).round().clamp(0, widget.entries.length - 1);

    if (newIndex != _currentIndex && newIndex < widget.entries.length) {
      _currentIndex = newIndex;
      widget.onPageChanged(newIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: SnapScrollPhysics(
        parent: const BouncingScrollPhysics(),
        cardWidth: widget.cardWidth,
        cardGap: widget.cardGap,
        startOffset: widget.containerPadding,
      ),
      itemCount: widget.entries.length + 1, // CC: Add ghost item for proper scrolling
      itemBuilder: (context, index) {
        // CC: Return ghost item for proper scrolling at the end
        // CC: Ghost item needs to be wide enough to allow last item to scroll to left position
        if (index >= widget.entries.length) {
          return SizedBox(width: widget.cardWidth + widget.cardGap);
        }

        final entry = widget.entries[index];
        final isSelected = index == widget.selectedIndex;

        return Container(
          width: widget.cardWidth,
          margin: EdgeInsets.only(
            right: index < widget.entries.length - 1 ? widget.cardGap : 0,
          ),
          child: AnimatedScale(
            scale: isSelected ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 200),
            child: AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.85,
              duration: const Duration(milliseconds: 200),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: NewspaperEntryCard(
                  entry: entry,
                  isSelected: isSelected,
                  categoryColor: widget.getCategoryColor?.call(entry.category),
                  onTap: () {
                    // CC: If we have a navigation callback, use it
                    if (widget.onEntryTap != null) {
                      widget.onEntryTap!(entry);
                    } else {
                      // CC: Otherwise, animate to tapped card
                      _scrollToIndex(index);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
