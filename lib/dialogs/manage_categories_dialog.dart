import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entry/cubit/entry_cubit.dart';

// Define callback types for clarity
typedef ShowEditCategoryDialogCallback =
    Future<String?> Function(BuildContext context, String oldCategoryName);
typedef ShowDeleteCategoryConfirmationDialogCallback =
    Future<bool> Function(BuildContext context, String category);

class ManageCategoriesDialog extends StatefulWidget {
  final ShowEditCategoryDialogCallback onShowEditCategoryDialog;
  final ShowDeleteCategoryConfirmationDialogCallback
  onShowDeleteCategoryConfirmationDialog;

  const ManageCategoriesDialog({
    super.key,
    required this.onShowEditCategoryDialog,
    required this.onShowDeleteCategoryConfirmationDialog,
  });

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog>
    with TickerProviderStateMixin {
  final _categoryInputController = TextEditingController();
  String _feedbackMessage = '';
  Timer? _feedbackTimer;
  late AnimationController _feedbackAnimationController;
  late Animation<double> _feedbackScaleAnimation;

  @override
  void initState() {
    super.initState();
    _feedbackAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _feedbackScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _feedbackAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _categoryInputController.dispose();
    _feedbackTimer?.cancel();
    _feedbackAnimationController.dispose();
    super.dispose();
  }

  void _showFeedback(String message) {
    _feedbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _feedbackMessage = message;
      });
      _feedbackAnimationController.forward(from: 0.0);
      _feedbackTimer = Timer(const Duration(seconds: 2, milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _feedbackMessage = '';
          });
        }
      });
    }
  }

  void _addCategory() {
    final newCategory = _categoryInputController.text.trim();
    if (newCategory.isNotEmpty) {
      HapticFeedback.mediumImpact();
      // Use context.read here as it's inside a method
      context.read<EntryCubit>().addCustomCategory(newCategory);
      _categoryInputController.clear();
      _showFeedback('Category "$newCategory" added');
    }
  }

  @override
  Widget build(BuildContext context) {
    // No need for StatefulBuilder here, the dialog itself is stateful
    // No need for BlocProvider.value, assuming EntryCubit is provided above this dialog
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Add custom categories or delete unused ones.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Flexible(
              child: BlocBuilder<EntryCubit, EntryState>(
                builder: (listBuilderContext, state) {
                  if (state.categories.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Text('No categories found.'),
                      ),
                    );
                  }
                  // Sort categories: Most recent first, Misc last
                  final List<String> displayCategories = List<String>.from(
                    state.categories,
                  );
                  displayCategories.remove('Misc');
                  final sortedCategories = displayCategories.reversed.toList();
                  sortedCategories.add('Misc');

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedCategories.length,
                    itemBuilder: (itemContext, index) {
                      final category = sortedCategories[index];
                      final bool isMisc = category == 'Misc';
                      return ListTile(
                        title: Text(
                          category,
                          style: TextStyle(color: isMisc ? Colors.grey : null),
                        ),
                        dense: true,
                        trailing:
                            isMisc
                                ? null
                                : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 20,
                                      ),
                                      tooltip: 'Rename Category',
                                      visualDensity: VisualDensity.compact,
                                      splashRadius: 20,
                                      onPressed: () async {
                                        // Use the callback passed to the widget
                                        final String? newName = await widget
                                            .onShowEditCategoryDialog(
                                              itemContext, // Use context from item builder
                                              category,
                                            );
                                        if (newName != null &&
                                            newName.isNotEmpty &&
                                            newName != category) {
                                          HapticFeedback.mediumImpact();
                                          _showFeedback(
                                            'Category renamed to "$newName"',
                                          );
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent[100],
                                        size: 20,
                                      ),
                                      tooltip: 'Delete Category',
                                      visualDensity: VisualDensity.compact,
                                      splashRadius: 20,
                                      onPressed: () async {
                                        // Use the callback passed to the widget
                                        bool confirmed = await widget
                                            .onShowDeleteCategoryConfirmationDialog(
                                              itemContext, // Use context from item builder
                                              category,
                                            );
                                        if (confirmed) {
                                          HapticFeedback.mediumImpact();
                                          // Cubit action is still needed here
                                          itemContext
                                              .read<EntryCubit>()
                                              .deleteCategory(category);
                                          _showFeedback(
                                            'Category "$category" deleted',
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 24),
            if (_feedbackMessage.isNotEmpty)
              ScaleTransition(
                scale: _feedbackScaleAnimation,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10.0, top: 4.0),
                  child: Text(
                    _feedbackMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: TextField(
                controller: _categoryInputController,
                decoration: InputDecoration(
                  labelText: 'New Category Name',
                  hintText: 'Enter category to add...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (value) => _addCategory(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Done'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: _addCategory,
          child: const Text('Add Category'),
        ),
      ],
    );
  }
}
