import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../entry/entry.dart';

// CP: Context menu that appears when long pressing an entry
class EntryContextMenu extends StatelessWidget {
  final Entry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopyText;
  final Offset position;

  const EntryContextMenu({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onCopyText,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // CP: Transparent background to dismiss menu when tapped
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
        ),
        // CP: Context menu positioned near tap location
        Positioned(
          left: position.dx,
          top: position.dy,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MenuOption(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onTap: () {
                        Navigator.of(context).pop();
                        onEdit();
                      },
                    ),
                    _MenuDivider(),
                    _MenuOption(
                      icon: Icons.copy_outlined,
                      label: 'Copy Text',
                      onTap: () {
                        Navigator.of(context).pop();
                        onCopyText();
                      },
                    ),
                    _MenuDivider(),
                    _MenuOption(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      textColor: Colors.redAccent,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDelete();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? textColor;

  const _MenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor =
        textColor ?? Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: effectiveTextColor),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: effectiveTextColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
    );
  }
}
