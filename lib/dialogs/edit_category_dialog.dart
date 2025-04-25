import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/entry_cubit.dart';

class EditCategoryDialog extends StatefulWidget {
  final String oldCategoryName;

  const EditCategoryDialog({super.key, required this.oldCategoryName});

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late final TextEditingController _editCategoryController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _editCategoryController = TextEditingController(
      text: widget.oldCategoryName,
    );
  }

  @override
  void dispose() {
    _editCategoryController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (_formKey.currentState!.validate()) {
      final newName = _editCategoryController.text.trim();
      // Call the cubit method
      context.read<EntryCubit>().renameCategory(
        widget.oldCategoryName,
        newName,
      );
      Navigator.of(context).pop(newName); // Return the new name
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Rename Category'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _editCategoryController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Category Name',
            hintText: 'Enter new name...',
          ),
          validator: (value) {
            final newName = value?.trim() ?? '';
            if (newName.isEmpty) {
              return 'Category name cannot be empty.';
            }
            if (newName == widget.oldCategoryName) {
              return 'Please enter a different name.';
            }
            // Check if the name already exists (case-insensitive)
            final existingCategories =
                context.read<EntryCubit>().state.categories;
            if (existingCategories.any(
              (cat) => cat.toLowerCase() == newName.toLowerCase(),
            )) {
              return 'Category "$newName" already exists.';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(), // Return null
        ),
        FilledButton(onPressed: _saveCategory, child: const Text('Save')),
      ],
    );
  }
}
