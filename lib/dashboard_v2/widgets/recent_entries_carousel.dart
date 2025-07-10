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
    // CC: Match the grid card width: (screenWidth - 32 padding - 12 gap) / 2
    final cardWidth = (screenWidth - 32 - 12) / 2;
    // CC: Adjusted viewport to show 2 cards at once with proper spacing
    final viewportFraction = (cardWidth + 12) / screenWidth;
    final pageController = PageController(
      initialPage: selectedIndex,
      viewportFraction: viewportFraction,
    );

    return SizedBox(
      key: recentEntriesCarouselKey,
      height: cardWidth, // CC: Square cards to match grid
      child: PageView.builder(
        controller: pageController,
        onPageChanged: (index) {
          // CC: Don't allow selecting the empty slot
          if (index < entries.length) {
            onPageChanged(index);
          }
        },
        itemCount: entries.length + 1, // CC: Add extra slot for scrolling to last item
        padEnds: false, // CC: Keep left alignment
        itemBuilder: (context, index) {
          // CC: Return empty container for the extra slot
          if (index >= entries.length) {
            return SizedBox(width: cardWidth);
          }

          final entry = entries[index];
          final isSelected = index == selectedIndex;

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 6, // CC: First card gets full left padding
              right: 6, // CC: Consistent spacing between cards
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
                        pageController.animateToPage(
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
