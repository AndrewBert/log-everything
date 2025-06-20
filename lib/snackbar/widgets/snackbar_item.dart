import 'package:flutter/material.dart';
import '../models/snackbar_message.dart';

class SnackbarItem extends StatefulWidget {
  const SnackbarItem({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final SnackbarMessage message;
  final VoidCallback onDismiss;

  @override
  State<SnackbarItem> createState() => _SnackbarItemState();
}

// todo add the ability to swipe snack bars up and away, but it kind of freezes at the end of the animation so I have to test what it looks like in release mode and fix it if it still exists there.
class _SnackbarItemState extends State<SnackbarItem> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // For swipe gesture
  double _dragOffset = 0.0;
  bool _isDragging = false;
  AnimationController? _snapBackController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation =
        Tween<double>(
          begin: -1.2,
          end: 0.0,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.elasticOut,
          ),
        );

    _fadeAnimation =
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
          ),
        );

    _animationController.forward();

    Future.delayed(widget.message.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _snapBackController?.dispose();
    super.dispose();
  }

  void _dismiss() {
    _animationController
        .animateTo(
          0.0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInCubic,
        )
        .then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
      // Allow dragging up, but never below the original position (0)
      _dragOffset = _dragOffset.clamp(-200.0, 0.0);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    const dismissThreshold = -50.0; // 50px upward swipe to dismiss

    if (_dragOffset < dismissThreshold && details.velocity.pixelsPerSecond.dy < 0) {
      // Trigger dismissal only if dragged up enough AND final velocity is upward
      _dismiss();
    } else {
      // Dispose previous snap-back controller if it exists
      _snapBackController?.dispose();

      // Animate back to original position
      _snapBackController = AnimationController(
        duration: const Duration(milliseconds: 200),
        vsync: this,
      );

      final animation =
          Tween<double>(
            begin: _dragOffset,
            end: 0.0,
          ).animate(
            CurvedAnimation(
              parent: _snapBackController!,
              curve: Curves.easeOut,
            ),
          );

      animation.addListener(() {
        if (mounted) {
          setState(() {
            _dragOffset = animation.value;
          });
        }
      });

      animation.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() {
            _isDragging = false;
          });
        }
      });

      _snapBackController!.forward();
    }
  }

  Color _getBackgroundColor(BuildContext context) {
    // Use theme surface color for consistency
    return Theme.of(context).colorScheme.surface;
  }

  Color _getAccentColor(BuildContext context) {
    // Use theme outline color for subtle border
    return Theme.of(context).colorScheme.outline.withValues(alpha: 0.2);
  }

  Color _getIconColor(BuildContext context) {
    // Use theme primary color with subtle variations for different types
    final primary = Theme.of(context).colorScheme.primary;
    switch (widget.message.type) {
      case SnackbarType.success:
        return primary; // Main theme color for success
      case SnackbarType.error:
        return Theme.of(context).colorScheme.error;
      case SnackbarType.warning:
        return primary.withValues(alpha: 0.8); // Slightly muted primary
      case SnackbarType.info:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  IconData _getIcon() {
    switch (widget.message.type) {
      case SnackbarType.success:
        return Icons.check_circle;
      case SnackbarType.error:
        return Icons.error;
      case SnackbarType.warning:
        return Icons.warning;
      case SnackbarType.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value * 60 + _dragOffset),
            child: Opacity(
              opacity:
                  _fadeAnimation.value * (1.0 - (_dragOffset < 0 ? _dragOffset.abs() / 200.0 : 0.0).clamp(0.0, 0.3)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: _getBackgroundColor(context),
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(
                    color: _getAccentColor(context),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6.0,
                      offset: const Offset(0, 2),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      _getIcon(),
                      color: _getIconColor(context),
                      size: 14.0,
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Text(
                        widget.message.message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w400,
                          height: 1.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (widget.message.actionLabel != null) ...[
                      const SizedBox(width: 12.0),
                      TextButton(
                        onPressed: () {
                          widget.message.onActionPressed?.call();
                          _dismiss();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          minimumSize: const Size(44.0, 44.0), // Accessibility minimum
                          tapTargetSize: MaterialTapTargetSize.padded,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: Text(
                          widget.message.actionLabel!,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 12.0,
                            decoration: TextDecoration.underline,
                            decorationColor: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 4.0),
                    SizedBox(
                      width: 44.0,
                      height: 44.0,
                      child: IconButton(
                        onPressed: _dismiss,
                        padding: EdgeInsets.zero,
                        iconSize: 16.0,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
