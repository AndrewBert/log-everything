import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/category.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/widget_keys.dart';
import 'delete_category_confirmation_dialog.dart';

// CP: Result class for edit category dialog operations
class EditCategoryResult {
  final EditCategoryOperation operation;
  final String? newCategoryName;
  final String? deletedCategoryName;

  const EditCategoryResult.renamed(this.newCategoryName)
    : operation = EditCategoryOperation.renamed,
      deletedCategoryName = null;

  const EditCategoryResult.deleted(this.deletedCategoryName)
    : operation = EditCategoryOperation.deleted,
      newCategoryName = null;

  const EditCategoryResult.cancelled()
    : operation = EditCategoryOperation.cancelled,
      newCategoryName = null,
      deletedCategoryName = null;
}

enum EditCategoryOperation { renamed, deleted, cancelled }

class EditCategoryDialog extends StatefulWidget {
  final String oldCategoryName;
  final bool focusDescription;

  const EditCategoryDialog({super.key, required this.oldCategoryName, this.focusDescription = false});

  @override
  State<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends State<EditCategoryDialog> {
  late final TextEditingController _editCategoryController;
  late final TextEditingController _descriptionController; // Controller for description
  late final FocusNode _descriptionFocusNode;
  final _formKey = GlobalKey<FormState>();
  bool _isChecklist = false; // Track checklist setting

  @override
  void initState() {
    super.initState();
    _editCategoryController = TextEditingController(text: widget.oldCategoryName);
    _descriptionFocusNode = FocusNode();
    // Pre-fill with existing description and checklist setting if editing
    final categories = context.read<EntryCubit>().state.categories;
    final existing = categories.firstWhere(
      (cat) => cat.name == widget.oldCategoryName,
      orElse: () => Category(name: widget.oldCategoryName),
    );
    _descriptionController = TextEditingController(text: existing.description);
    _isChecklist = existing.isChecklist;
    
    // Focus description field if requested
    if (widget.focusDescription) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _descriptionFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _editCategoryController.dispose();
    _descriptionController.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  void _saveCategory() {
    if (_formKey.currentState!.validate()) {
      final newName = _editCategoryController.text.trim();
      final newDescription = _descriptionController.text.trim();
      // Call cubit method to update name, description, and checklist setting
      context.read<EntryCubit>().renameCategory(widget.oldCategoryName, newName, 
          description: newDescription, isChecklist: _isChecklist);
      Navigator.of(context).pop(EditCategoryResult.renamed(newName)); // Return result object
    }
  }

  Future<void> _deleteCategory() async {
    // CP: Show confirmation dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => DeleteCategoryConfirmationDialog(category: widget.oldCategoryName),
    );
    if (confirmed == true && mounted) {
      // CP: Delete the category
      context.read<EntryCubit>().deleteCategory(widget.oldCategoryName);
      // CP: Return result object indicating deletion
      Navigator.of(context).pop(EditCategoryResult.deleted(widget.oldCategoryName));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Category'),
      content: SizedBox(
        width: double.maxFinite,
        height: 240, // CP: Increased height to accommodate checklist toggle
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _editCategoryController,
                decoration: InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'Enter new name...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (value) {
                  final newName = value?.trim() ?? '';
                  if (newName.isEmpty) {
                    return 'Category name cannot be empty.';
                  }
                  // CP: Only block if the new name is different and already exists
                  final existingCategories = context.read<EntryCubit>().state.categories;
                  final isNameChanged = newName != widget.oldCategoryName;
                  final nameExists = existingCategories.any((cat) => cat.name.toLowerCase() == newName.toLowerCase());
                  if (isNameChanged && nameExists) {
                    return 'Category "$newName" already exists.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Describe this category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    controller: _descriptionController,
                    focusNode: _descriptionFocusNode,
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Helps AI sort better',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // CP: Checklist toggle
              Row(
                children: [
                  Icon(Icons.checklist, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use as Checklist',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Switch(
                    key: editCategoryChecklistToggle,
                    value: _isChecklist,
                    onChanged: (value) => setState(() => _isChecklist = value),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            // CP: Delete button on the left
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: _deleteCategory,
              child: const Text('Delete'),
            ),
            const Spacer(),
            // CP: Cancel and Save buttons on the right
            TextButton(
              onPressed: () => Navigator.of(context).pop(EditCategoryResult.cancelled()), // Return cancelled result
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _saveCategory, 
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
