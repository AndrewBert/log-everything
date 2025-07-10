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
    // CC: Calculate card width to fit exactly 2 cards between insight container edges
    // Total space = screenWidth - 32px (insight margins) - 16px (card's left padding)
    final cardGap = 4.0;
    final totalAvailableWidth = screenWidth - 32 - 16;
    final cardWidth = (totalAvailableWidth - cardGap) / 2;

    // CC: Viewport = one card + gap + left padding to ensure proper scrolling
    final viewportFraction = (cardWidth + cardGap + 16) / screenWidth;

    final carouselController = CarouselSliderController();

    return SizedBox(
      key: recentEntriesCarouselKey,
      height: cardWidth,
      child: CarouselSlider.builder(
        carouselController: carouselController,
        options: CarouselOptions(
          height: cardWidth,
          viewportFraction: viewportFraction,
          initialPage: selectedIndex,
          enableInfiniteScroll: false,
          onPageChanged: (index, reason) {
            if (index < entries.length) {
              onPageChanged(index);
            }
          },
          padEnds: false,
          enlargeCenterPage: false,
          pageSnapping: true,
          scrollDirection: Axis.horizontal,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index, realIndex) {
          final entry = entries[index];
          final isSelected = index == selectedIndex;

          return Padding(
            padding: EdgeInsets.only(
              left: 16.0, // CC: All cards have consistent left padding
              right: cardGap,
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
