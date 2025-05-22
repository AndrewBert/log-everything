import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/category.dart';
import '../entry/cubit/entry_cubit.dart';

class EditCategoryDialog extends StatefulWidget {
  final String oldCategoryName;

  const EditCategoryDialog({super.key, required this.oldCategoryName});

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late final TextEditingController _editCategoryController;
  late final TextEditingController
  _descriptionController; // Controller for description
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _editCategoryController = TextEditingController(
      text: widget.oldCategoryName,
    );
    // Pre-fill with existing description if editing
    final categories = context.read<EntryCubit>().state.categories;
    final existing = categories.firstWhere(
      (cat) => cat.name == widget.oldCategoryName,
      orElse: () => Category(name: widget.oldCategoryName),
    );
    _descriptionController = TextEditingController(text: existing.description);
  }

  @override
  void dispose() {
    _editCategoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (_formKey.currentState!.validate()) {
      final newName = _editCategoryController.text.trim();
      final newDescription = _descriptionController.text.trim();
      // Call cubit method to update name and description
      context.read<EntryCubit>().renameCategory(
        widget.oldCategoryName,
        newName,
        description: newDescription,
      );
      Navigator.of(context).pop(newName); // Return the new name
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Category'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _editCategoryController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'Enter new name...',
              ),
              validator: (value) {
                final newName = value?.trim() ?? '';
                if (newName.isEmpty) {
                  return 'Category name cannot be empty.';
                }
                // CP: Only block if the new name is different and already exists
                final existingCategories =
                    context.read<EntryCubit>().state.categories;
                final isNameChanged = newName != widget.oldCategoryName;
                final nameExists = existingCategories.any(
                  (cat) => cat.name.toLowerCase() == newName.toLowerCase(),
                );
                if (isNameChanged && nameExists) {
                  return 'Category "$newName" already exists.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText:
                    'Describe this category for better auto-categorization',
              ),
              controller: _descriptionController,
              minLines: 3, // CP: Make the description field larger when editing
              maxLines: 5, // CP: Allow up to 5 lines for editing
            ),
          ],
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
