import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/entry_cubit.dart';
import '../entry.dart';

// todo refactor to use bloc and make stateless
class EditEntryDialog extends StatefulWidget {
  final Entry originalEntry;

  const EditEntryDialog({super.key, required this.originalEntry});

  @override
  State<EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<EditEntryDialog> {
  late final TextEditingController _editController;
  late String _selectedCategory;
  late List<String> _availableCategories;
  final _formKey = GlobalKey<FormState>(); // Add form key for validation

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.originalEntry.text);
    _selectedCategory = widget.originalEntry.category;

    // Get categories from cubit
    final currentState = context.read<EntryCubit>().state;
    _availableCategories = List<String>.from(currentState.categories)..sort();

    // Ensure the current category is valid, default to Misc if not
    if (!_availableCategories.contains(_selectedCategory)) {
      _selectedCategory = 'Misc';
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  void _updateEntry() {
    if (_formKey.currentState!.validate()) {
      final updatedText = _editController.text.trim();
      final updatedEntry = Entry(
        text: updatedText,
        category: _selectedCategory,
        timestamp: widget.originalEntry.timestamp,
      );
      context.read<EntryCubit>().updateEntry(
        widget.originalEntry,
        updatedEntry,
      );
      Navigator.of(context).pop(updatedEntry); // Return the updated entry
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Edit Entry'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _editController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Entry Text',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Entry text cannot be empty.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items:
                  _availableCategories.map((String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedCategory = newValue;
                  });
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(), // Return null
        ),
        FilledButton(onPressed: _updateEntry, child: const Text('Update')),
      ],
    );
  }
}
