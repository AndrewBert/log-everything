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
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isVisible ? 16 : 0,
      child: Center(
        child: Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ),
    );
  }
}