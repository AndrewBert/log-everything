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

    // CC: Viewport fraction to show 2 cards with peek of adjacent cards
    final viewportFraction = (cardWidth + cardGap) / screenWidth;

    return Container(
      key: recentEntriesCarouselKey,
      height: cardWidth,
      margin: EdgeInsets.only(left: containerPadding),
      child: _PageViewCarousel(
        entries: entries,
        selectedIndex: selectedIndex,
        onPageChanged: onPageChanged,
        onEntryTap: onEntryTap,
        getCategoryColor: getCategoryColor,
        viewportFraction: viewportFraction,
        cardWidth: cardWidth,
        cardGap: cardGap,
      ),
    );
  }
}

class _PageViewCarousel extends StatefulWidget {
  final List<Entry> entries;
  final int selectedIndex;
  final Function(int) onPageChanged;
  final Function(Entry)? onEntryTap;
  final Color? Function(String)? getCategoryColor;
  final double viewportFraction;
  final double cardWidth;
  final double cardGap;

  const _PageViewCarousel({
    required this.entries,
    required this.selectedIndex,
    required this.onPageChanged,
    this.onEntryTap,
    this.getCategoryColor,
    required this.viewportFraction,
    required this.cardWidth,
    required this.cardGap,
  });

  @override
  State<_PageViewCarousel> createState() => _PageViewCarouselState();
}

class _PageViewCarouselState extends State<_PageViewCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.selectedIndex;
    _pageController = PageController(
      initialPage: widget.selectedIndex,
      viewportFraction: widget.viewportFraction,
    );
  }

  @override
  void didUpdateWidget(_PageViewCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CC: Animate to new index when selectedIndex changes externally
    if (widget.selectedIndex != oldWidget.selectedIndex &&
        widget.selectedIndex != _currentPage &&
        widget.entries.isNotEmpty) {
      if (widget.selectedIndex < widget.entries.length) {
        _currentPage = widget.selectedIndex;
        _pageController.animateToPage(
          widget.selectedIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }

    // CC: Handle entries list changes - recreate controller if needed
    if (widget.entries.length != oldWidget.entries.length) {
      final newIndex = widget.selectedIndex.clamp(0, widget.entries.length - 1);
      _currentPage = newIndex;
      _pageController.dispose();
      _pageController = PageController(
        initialPage: newIndex,
        viewportFraction: widget.viewportFraction,
      );
    }
  }

  void _onPageChanged(int page) {
    if (page < widget.entries.length) {
      _currentPage = page;
      widget.onPageChanged(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: widget.entries.length + 1, // CC: Add ghost item for scrolling
      itemBuilder: (context, index) {
        // CC: Return empty container for ghost item
        if (index >= widget.entries.length) {
          return SizedBox(width: widget.cardWidth);
        }

        final entry = widget.entries[index];
        final isSelected = index == widget.selectedIndex;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.cardGap / 2,
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
                    // CP: If we have a navigation callback, use it
                    if (widget.onEntryTap != null) {
                      widget.onEntryTap!(entry);
                    } else {
                      // CP: Otherwise, animate to tapped card
                      _currentPage = index;
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
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
    _pageController.dispose();
    super.dispose();
  }
}
