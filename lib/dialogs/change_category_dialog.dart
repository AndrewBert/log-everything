import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChangeCategoryDialog extends StatelessWidget {
  final String? currentCategory;
  final List<String> availableCategories;

  const ChangeCategoryDialog({super.key, required this.currentCategory, required this.availableCategories});

  // Helper to map backend 'Misc' to frontend 'None' and vice versa
  String categoryDisplayName(String category) => category == 'Misc' ? 'None' : category;
  String categoryBackendValue(String displayName) => displayName == 'None' ? 'Misc' : displayName;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Change Category'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      children:
          availableCategories.map((category) {
            final display = categoryDisplayName(category); // Show 'None' for 'Misc'
            return SimpleDialogOption(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(
                  context,
                  categoryBackendValue(display), // Return backend value
                ); // Return the selected category
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
