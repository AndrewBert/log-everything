import 'package:flutter/material.dart';

class ConnectingLine extends StatelessWidget {
  final bool isVisible;

  const ConnectingLine({
    super.key,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // CC: Calculate card width matching the carousel calculation
    // Updated to match new carousel spacing: containerPadding = 12.0, cardGap = 4.0
    final containerPadding = 12.0;
    final cardGap = 4.0;
    final cardWidth = (screenWidth - (containerPadding * 2) - cardGap) / 2;
    // CC: Center of first card = container padding + half card width
    final linePosition = containerPadding + (cardWidth / 2);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isVisible ? 16 : 0,
      child: Stack(
        children: [
          Positioned(
            left: linePosition - 1.5, // CC: Center the 3px wide line
            child: Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
