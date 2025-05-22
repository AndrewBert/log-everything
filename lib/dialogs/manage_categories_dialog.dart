import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/category.dart';
import '../entry/cubit/entry_cubit.dart';

// Define callback types for clarity
typedef ShowEditCategoryDialogCallback =
    Future<String?> Function(BuildContext context, String oldCategoryName);
typedef ShowDeleteCategoryConfirmationDialogCallback =
    Future<bool> Function(BuildContext context, String category);

// Helper to map backend 'Misc' to frontend 'None' and vice versa
String categoryDisplayName(String category) =>
    category == 'Misc' ? 'None' : category;
String categoryBackendValue(String displayName) =>
    displayName == 'None' ? 'Misc' : displayName;

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
  final _descriptionInputController =
      TextEditingController(); // Controller for new category description

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _categoryInputController.dispose();
    _descriptionInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Manage Categories'),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: () async {
              final entryCubit =
                  context.read<EntryCubit>(); // CP: Get cubit before async
              final rootNavigator = Navigator.of(
                context,
                rootNavigator: true,
              ); // CP: Get navigator before async
              final result = await showDialog<Map<String, String>?>(
                context: context,
                builder: (dialogContext) => const AddCategoryDialog(),
              );
              if (!mounted) return; // CP: Guard context after async gap
              if (result != null && result['name'] != null) {
                entryCubit.addCustomCategoryWithDescription(
                  result['name']!,
                  result['description'] ?? '',
                );
                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                  SnackBar(content: Text('Category "${result['name']}" added')),
                );
              }
            },
          ),
        ],
      ),
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
              fit: FlexFit.loose,
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
                  final List<String> displayCategories = List<String>.from(
                    state.categories.map(
                      (cat) => categoryDisplayName(cat.name),
                    ),
                  );
                  displayCategories.remove('None');
                  final sortedCategories = displayCategories.reversed.toList();
                  sortedCategories.add('None');

                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedCategories.length,
                    itemBuilder: (itemContext, index) {
                      final category = sortedCategories[index];
                      final bool isNone = category == 'None';
                      final Category catObj = state.categories.firstWhere(
                        (cat) => categoryDisplayName(cat.name) == category,
                        orElse: () => Category(name: category),
                      );
                      return ListTile(
                        title: Text(
                          category,
                          style: TextStyle(color: isNone ? Colors.grey : null),
                        ),
                        subtitle:
                            (catObj.description.isNotEmpty && !isNone)
                                ? Tooltip(
                                  message: catObj.description,
                                  child: Text(
                                    catObj.description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                )
                                : null,
                        dense: true,
                        trailing:
                            isNone
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
                                        final onShowEditCategoryDialog =
                                            widget.onShowEditCategoryDialog;
                                        final rootNavigator = Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ); // CP: Get navigator before async
                                        final result =
                                            await onShowEditCategoryDialog(
                                              itemContext,
                                              categoryBackendValue(category),
                                            );
                                        if (!mounted) {
                                          return; // CP: Guard context after async gap
                                        }
                                        final newName = result;
                                        if (newName != null &&
                                            newName.isNotEmpty &&
                                            newName != category) {
                                          HapticFeedback.mediumImpact();
                                          ScaffoldMessenger.of(
                                            rootNavigator.context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Category renamed to "${categoryDisplayName(newName)}"',
                                              ),
                                            ),
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
                                        final entryCubit =
                                            itemContext
                                                .read<
                                                  EntryCubit
                                                >(); // CP: Get cubit before async
                                        final onShowDeleteCategoryConfirmationDialog =
                                            widget
                                                .onShowDeleteCategoryConfirmationDialog;
                                        final rootNavigator = Navigator.of(
                                          context,
                                          rootNavigator: true,
                                        ); // CP: Get navigator before async
                                        final confirmed =
                                            await onShowDeleteCategoryConfirmationDialog(
                                              itemContext,
                                              categoryBackendValue(category),
                                            );
                                        if (!mounted) {
                                          return; // CP: Guard context after async gap
                                        }
                                        if (confirmed && itemContext.mounted) {
                                          HapticFeedback.mediumImpact();
                                          entryCubit.deleteCategory(
                                            categoryBackendValue(category),
                                          );
                                          ScaffoldMessenger.of(
                                            rootNavigator.context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Category "${categoryDisplayName(category)}" deleted',
                                              ),
                                            ),
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
          ],
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Done'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class AddCategoryDialog extends StatelessWidget {
  const AddCategoryDialog({super.key});

  @override
  Widget build(BuildContext context) {
    // CP: Remove leading underscores from local variables
    final categoryInputController = TextEditingController();
    final descriptionInputController = TextEditingController();
    // CP: FocusNode to auto-focus the category name field
    final categoryFocusNode = FocusNode();

    // CP: Request focus when the dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      categoryFocusNode.requestFocus();
    });

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              controller: categoryInputController,
              focusNode: categoryFocusNode, // CP: Auto-focus here
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              controller: descriptionInputController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText:
                    'Describe this category for better auto-categorization',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: () {
            final name = categoryInputController.text.trim();
            final description = descriptionInputController.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(
                context,
              ).pop({'name': name, 'description': description});
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
