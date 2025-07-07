import 'package:flutter/material.dart';

class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({super.key});

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surface;
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - 32; // CC: Account for padding
            
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CP: Icon and title placeholder
                  Row(
                    children: [
                      _buildShimmerBox(
                        width: 20,
                        height: 20,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        borderRadius: 4,
                      ),
                      const SizedBox(width: 12),
                      _buildShimmerBox(
                        width: 100,
                        height: 16,
                        baseColor: baseColor,
                        highlightColor: highlightColor,
                        borderRadius: 8,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // CP: Content placeholder lines
                  _buildShimmerBox(
                    width: availableWidth,
                    height: 12,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    borderRadius: 6,
                  ),
                  const SizedBox(height: 8),
                  _buildShimmerBox(
                    width: availableWidth * 0.75,
                    height: 12,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    borderRadius: 6,
                  ),
                  const SizedBox(height: 8),
                  _buildShimmerBox(
                    width: availableWidth * 0.6,
                    height: 12,
                    baseColor: baseColor,
                    highlightColor: highlightColor,
                    borderRadius: 6,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildShimmerBox({
    required double width,
    required double height,
    required Color baseColor,
    required Color highlightColor,
    required double borderRadius,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Container(
              width: width,
              height: height,
              color: baseColor,
            ),
            Positioned(
              left: _animation.value * width,
              top: 0,
              bottom: 0,
              width: width * 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      highlightColor.withValues(alpha: 0),
                      highlightColor.withValues(alpha: 0.5),
                      highlightColor.withValues(alpha: 0),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}