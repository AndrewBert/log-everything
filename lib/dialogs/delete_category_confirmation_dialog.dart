import 'package:flutter/material.dart';

class DeleteCategoryConfirmationDialog extends StatelessWidget {
  final String category;

  const DeleteCategoryConfirmationDialog({super.key, required this.category});

  // Helper to map backend 'Misc' to frontend 'None'
  String categoryDisplayName(String category) => category == 'Misc' ? 'None' : category;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Confirm Delete Category'),
      content: Text(
        '''Are you sure you want to delete the category "${categoryDisplayName(category)}"?
Entries using this category will be moved to "None".''',
      ),
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
