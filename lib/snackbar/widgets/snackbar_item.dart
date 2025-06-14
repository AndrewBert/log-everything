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

class _SnackbarItemState extends State<SnackbarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.2,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

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
    super.dispose();
  }

  void _dismiss() {
    _animationController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInCubic,
    ).then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  Color _getBackgroundColor(BuildContext context) {
    // Neutral light background
    return const Color(0xFFF8F9FA);
  }

  Color _getAccentColor(BuildContext context) {
    switch (widget.message.type) {
      case SnackbarType.success:
        return const Color(0xFF10B981).withValues(alpha: 0.3);
      case SnackbarType.error:
        return const Color(0xFFEF4444).withValues(alpha: 0.3);
      case SnackbarType.warning:
        return const Color(0xFFF59E0B).withValues(alpha: 0.3);
      case SnackbarType.info:
        return const Color(0xFF3B82F6).withValues(alpha: 0.3);
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (widget.message.type) {
      case SnackbarType.success:
        return const Color(0xFF10B981);
      case SnackbarType.error:
        return const Color(0xFFEF4444);
      case SnackbarType.warning:
        return const Color(0xFFF59E0B);
      case SnackbarType.info:
        return const Color(0xFF3B82F6);
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
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * 60),
          child: Opacity(
            opacity: _fadeAnimation.value,
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
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8.0,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6.0),
                    decoration: BoxDecoration(
                      color: _getAccentColor(context),
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Icon(
                      _getIcon(),
                      color: _getIconColor(context),
                      size: 16.0,
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      widget.message.message,
                      style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (widget.message.actionLabel != null) ...[
                    const SizedBox(width: 12.0),
                    Container(
                      decoration: BoxDecoration(
                        color: _getAccentColor(context),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: _getIconColor(context),
                          width: 1.0,
                        ),
                      ),
                      child: TextButton(
                        onPressed: () {
                          widget.message.onActionPressed?.call();
                          _dismiss();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: _getIconColor(context),
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6.0),
                          ),
                        ),
                        child: Text(
                          widget.message.actionLabel!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.0,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8.0),
                  GestureDetector(
                    onTap: _dismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.black.withValues(alpha: 0.6),
                        size: 14.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}