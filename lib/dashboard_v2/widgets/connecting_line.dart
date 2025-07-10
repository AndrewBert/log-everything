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
    final cardWidth = (screenWidth - 32 - 12) / 2;
    // CC: Center of first card = base padding (16) + half card width
    final linePosition = 16.0 + (cardWidth / 2);
    
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
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}