import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChangeCategoryDialog extends StatelessWidget {
  final String? currentCategory;
  final List<String> availableCategories;

  const ChangeCategoryDialog({
    super.key,
    required this.currentCategory,
    required this.availableCategories,
  });

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Change Category'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      children:
          availableCategories.map((category) {
            return SimpleDialogOption(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.pop(
                  context,
                  category,
                ); // Return the selected category
              },
              child: Text(
                category,
                style: TextStyle(
                  fontWeight:
                      category == currentCategory
                          ? FontWeight.bold
                          : FontWeight.normal,
                  color:
                      category == currentCategory
                          ? Theme.of(context).colorScheme.primary
                          : null,
                ),
              ),
            );
          }).toList(),
    );
  }
}
