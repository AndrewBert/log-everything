import 'package:flutter/material.dart';
import 'package:myapp/dashboard_v2/dashboard_v2_barrel.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class RecentEntriesCarousel extends StatelessWidget {
  final List<Entry> entries;
  final int selectedIndex;
  final Function(int) onPageChanged;
  
  const RecentEntriesCarousel({
    super.key,
    required this.entries,
    required this.selectedIndex,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // CP: Calculate card width to show 2 cards plus a peek of the third
    final cardWidth = (screenWidth - 48) / 2.2; // 48 = padding (16*2) + spacing (16)
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
              left: index == 0 ? 16 : 8,
              right: index == entries.length - 1 ? 16 : 8,
            ),
            child: AnimatedScale(
              scale: isSelected ? 1.0 : 0.95,
              duration: const Duration(milliseconds: 200),
              child: AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.7,
                duration: const Duration(milliseconds: 200),
                child: SquareEntryCard(
                  entry: entry,
                  onTap: () {
                    // CP: Animate to tapped card
                    pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}