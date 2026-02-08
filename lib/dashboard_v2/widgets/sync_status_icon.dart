import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/services/firestore_sync_service.dart';
import 'package:myapp/sync_status/cubit/sync_status_cubit.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

// CP: Animated cloud icon in the app bar that reflects Firestore sync status.
// Shows nothing when idle, cloud_upload when syncing, cloud_done when synced,
// cloud_off when an error occurred.
class SyncStatusIcon extends StatelessWidget {
  const SyncStatusIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncStatusCubit, SyncStatus>(
      builder: (context, status) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: status == SyncStatus.idle
              ? const SizedBox.shrink(key: ValueKey('idle'))
              : _buildIcon(context, status),
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context, SyncStatus status) {
    final IconData icon;
    final Color color;
    final String tooltip;

    switch (status) {
      case SyncStatus.syncing:
        icon = Icons.cloud_upload_outlined;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        tooltip = 'Syncing...';
      case SyncStatus.synced:
        icon = Icons.cloud_done_outlined;
        color = Colors.green;
        tooltip = 'All changes saved';
      case SyncStatus.error:
        icon = Icons.cloud_off_outlined;
        color = Theme.of(context).colorScheme.error;
        tooltip = 'Sync failed';
      case SyncStatus.idle:
        icon = Icons.cloud_done_outlined;
        color = Colors.transparent;
        tooltip = '';
    }

    Widget iconWidget = Icon(icon, size: 20, color: color);

    // CP: Add rotation animation for syncing state
    if (status == SyncStatus.syncing) {
      iconWidget = _SyncingIcon(icon: icon, color: color);
    }

    return Tooltip(
      key: ValueKey(status),
      message: tooltip,
      child: Padding(
        key: syncStatusIconKey,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: iconWidget,
      ),
    );
  }
}

// CP: Pulsing animation for the syncing state icon
class _SyncingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;

  const _SyncingIcon({required this.icon, required this.color});

  @override
  State<_SyncingIcon> createState() => _SyncingIconState();
}

class _SyncingIconState extends State<_SyncingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(widget.icon, size: 20, color: widget.color),
    );
  }
}
