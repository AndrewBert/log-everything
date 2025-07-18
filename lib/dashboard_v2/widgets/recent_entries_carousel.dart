import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class RecentEntriesCarousel extends StatelessWidget {
  final List<Entry> entries;
  final int selectedIndex;
  final Function(int) onPageChanged;
  final Function(Entry)? onEntryTap;

  const RecentEntriesCarousel({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onPageChanged,
    this.onEntryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // CC: Requirements: 2 full cards visible, left-aligned with insight, peeking on sides
    final containerPadding = 16.0;
    final cardGap = 8.0;

    // CC: Calculate card width to fit 2 cards within container
    final availableWidth = screenWidth - (containerPadding * 2);
    final cardWidth = (availableWidth - cardGap) / 2;

    // CC: Viewport fraction slightly larger to show peek of next card
    // Add extra space for gap to ensure proper peek visibility
    final viewportFraction = (cardWidth + cardGap) / screenWidth;

    final carouselController = CarouselSliderController();

    // CC: Wrap in Container with margin to maintain alignment
    // TODO: Left side peek has minor glitching/offloading issue - revisit later
    return Container(
      key: recentEntriesCarouselKey,
      height: cardWidth,
      margin: EdgeInsets.only(left: containerPadding),
      child: CarouselSlider.builder(
        carouselController: carouselController,
        options: CarouselOptions(
          height: cardWidth,
          viewportFraction: viewportFraction,
          clipBehavior: Clip.none,
          initialPage: selectedIndex,
          enableInfiniteScroll: false,
          onPageChanged: (index, reason) {
            if (index < entries.length) {
              onPageChanged(index);
            }
          },
          disableCenter: true,
          padEnds: false,
          enlargeCenterPage: false,
          pageSnapping: true,
          scrollDirection: Axis.horizontal,
        ),
        itemCount: entries.length + 1, // CC: Add ghost item for scrolling
        itemBuilder: (context, index, realIndex) {
          // CC: Return empty container for ghost item
          if (index >= entries.length) {
            return SizedBox(width: cardWidth);
          }

          final entry = entries[index];
          final isSelected = index == selectedIndex;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: cardGap / 2,
            ),
            child: AnimatedScale(
              scale: isSelected ? 1.0 : 0.95,
              duration: const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 200),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: SquareEntryCard(
                    entry: entry,
                    isSelected: isSelected,
                    onTap: () {
                      // CP: If we have a navigation callback, use it
                      if (onEntryTap != null) {
                        onEntryTap!(entry);
                      } else {
                        // CP: Otherwise, animate to tapped card
                        carouselController.animateToPage(
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
      ),
    );
  }
}
