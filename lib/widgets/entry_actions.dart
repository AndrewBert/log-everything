import 'package:flutter/material.dart';
import '../entry/entry.dart';
import '../utils/widget_keys.dart'; // Import keys

class EntryActions extends StatelessWidget {
  final Entry entry;
  final bool isProcessing;
  final VoidCallback onEditPressed;
  final VoidCallback onDeletePressed;

  const EntryActions({
    super.key,
    required this.entry,
    required this.isProcessing,
    required this.onEditPressed,
    required this.onDeletePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isProcessing)
          const Padding(
            padding: EdgeInsets.only(right: 4.0),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.0),
            ),
          ),
        IconButton(
          key: entryDeleteIconKey(entry), // Add key for delete icon
          icon: Icon(
            Icons.delete_outline,
            color: Colors.redAccent.shade100,
            size: 18,
          ),
          tooltip: 'Delete Entry',
          visualDensity: VisualDensity.compact,
          splashRadius: 20,
          onPressed: isProcessing ? null : onDeletePressed,
        ),
      ],
    );
  }
}
