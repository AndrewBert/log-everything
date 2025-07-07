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
    final pageController = PageController(
      initialPage: selectedIndex,
      viewportFraction: cardWidth / screenWidth,
    );

    return SizedBox(
      key: recentEntriesCarouselKey,
      height: cardWidth, // CP: Square cards
      child: PageView.builder(
        controller: pageController,
        onPageChanged: onPageChanged,
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isSelected = index == selectedIndex;

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 16 : 6,
              right: index == entries.length - 1 ? 16 : 6,
            ),
            child: Center(
              child: AnimatedScale(
                scale: isSelected ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: AnimatedOpacity(
                  opacity: isSelected ? 1.0 : 0.6,
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
            ),
          );
        },
      ),
    );
  }
}
