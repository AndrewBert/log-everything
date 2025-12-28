import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:myapp/entry/category.dart';

class ChangeCategoryDialog extends StatelessWidget {
  final String? currentCategory;
  final List<String> availableCategories;

  const ChangeCategoryDialog({super.key, required this.currentCategory, required this.availableCategories});

  // CP: Use Category model's static helpers for display name mapping
  String _getDisplayName(String category) =>
      category == Category.miscName ? Category.miscDisplayName : category;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Change Category'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      children:
          availableCategories.map((category) {
            final display = _getDisplayName(category); // CP: Show 'None' for 'Misc'
            return SimpleDialogOption(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, category); // CP: Return the internal category name
              },
              child: Text(
                display,
                style: TextStyle(
                  fontWeight: category == currentCategory ? FontWeight.bold : FontWeight.normal,
                  color: category == currentCategory ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
            );
          }).toList(),
    );
  }
}
