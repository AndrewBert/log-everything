import 'package:flutter/material.dart';
import 'package:myapp/entry/category.dart';

class DeleteCategoryConfirmationDialog extends StatelessWidget {
  final String category;

  const DeleteCategoryConfirmationDialog({super.key, required this.category});

  // CP: Use Category model's static helpers for display name mapping
  String _getDisplayName(String category) =>
      category == Category.miscName ? Category.miscDisplayName : category;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirm Delete Category'),
      content: Text('''Are you sure you want to delete the category "${_getDisplayName(category)}"?
Entries using this category will be moved to "${Category.miscDisplayName}".'''),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(false), // Return false
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
          onPressed: () => Navigator.of(context).pop(true), // Return true
        ),
      ],
    );
  }
}
