import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/category.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';

// Define callback types for clarity
typedef ShowEditCategoryDialogCallback = Future<String?> Function(BuildContext context, String oldCategoryName);
typedef ShowDeleteCategoryConfirmationDialogCallback = Future<bool> Function(BuildContext context, String category);

// Helper to map backend 'Misc' to frontend 'None' and vice versa
String categoryDisplayName(String category) => category == 'Misc' ? 'None' : category;
String categoryBackendValue(String displayName) => displayName == 'None' ? 'Misc' : displayName;

class ManageCategoriesDialog extends StatefulWidget {
  final ShowEditCategoryDialogCallback onShowEditCategoryDialog;
  final ShowDeleteCategoryConfirmationDialogCallback onShowDeleteCategoryConfirmationDialog;

  const ManageCategoriesDialog({
    super.key,
    required this.onShowEditCategoryDialog,
    required this.onShowDeleteCategoryConfirmationDialog,
  });

  @override
  State<ManageCategoriesDialog> createState() => _ManageCategoriesDialogState();
}

class _ManageCategoriesDialogState extends State<ManageCategoriesDialog> with TickerProviderStateMixin {
  final _categoryInputController = TextEditingController();
  final _descriptionInputController = TextEditingController(); // Controller for new category description

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
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // CP: Fixed height to ensure proper layout
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Add custom categories or delete unused ones.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
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
                    state.categories.map((cat) => categoryDisplayName(cat.name)),
                  );
                  displayCategories.remove('None');
                  final sortedCategories = displayCategories.reversed.toList();
                  sortedCategories.add('None');
                  return ListView.builder(
                    itemCount: sortedCategories.length,
                    itemBuilder: (itemContext, index) {
                      final category = sortedCategories[index];
                      final bool isNone = category == 'None';
                      final Category catObj = state.categories.firstWhere(
                        (cat) => categoryDisplayName(cat.name) == category,
                        orElse: () => Category(name: category),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: CategoryCard(
                          category: catObj,
                          displayName: category,
                          isNone: isNone,
                          onEdit: () async {
                            final onShowEditCategoryDialog = widget.onShowEditCategoryDialog;
                            final rootNavigator = Navigator.of(
                              context,
                              rootNavigator: true,
                            ); // CP: Get navigator before async
                            final result = await onShowEditCategoryDialog(itemContext, categoryBackendValue(category));
                            if (!mounted) {
                              return; // CP: Guard context after async gap
                            }
                            final newName = result;
                            if (newName != null && newName.isNotEmpty && newName != category) {
                              HapticFeedback.mediumImpact();
                              ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                                SnackBar(content: Text('Category renamed to "${categoryDisplayName(newName)}"')),
                              );
                            }
                          },
                          onDelete: () async {
                            final entryCubit = itemContext.read<EntryCubit>(); // CP: Get cubit before async
                            final onShowDeleteCategoryConfirmationDialog =
                                widget.onShowDeleteCategoryConfirmationDialog;
                            final rootNavigator = Navigator.of(
                              context,
                              rootNavigator: true,
                            ); // CP: Get navigator before async
                            final confirmed = await onShowDeleteCategoryConfirmationDialog(
                              itemContext,
                              categoryBackendValue(category),
                            );
                            if (!mounted) {
                              return; // CP: Guard context after async gap
                            }
                            if (confirmed && itemContext.mounted) {
                              HapticFeedback.mediumImpact();
                              entryCubit.deleteCategory(categoryBackendValue(category));
                              ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                                SnackBar(content: Text('Category "${categoryDisplayName(category)}" deleted')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            // CP: Add category button at the bottom
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final entryCubit = context.read<EntryCubit>(); // CP: Get cubit before async
                    final rootNavigator = Navigator.of(context, rootNavigator: true); // CP: Get navigator before async
                    final result = await showDialog<Map<String, String>?>(
                      context: context,
                      builder: (dialogContext) => const AddCategoryDialog(),
                    );
                    if (!mounted) return; // CP: Guard context after async gap
                    if (result != null && result['name'] != null) {
                      entryCubit.addCustomCategoryWithDescription(result['name']!, result['description'] ?? '');
                      ScaffoldMessenger.of(
                        rootNavigator.context,
                      ).showSnackBar(SnackBar(content: Text('Category "${result['name']}" added')));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Category'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [TextButton(child: const Text('Done'), onPressed: () => Navigator.of(context).pop())],
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
              textCapitalization: TextCapitalization.words, // CP: Auto-capitalize each word
              decoration: InputDecoration(
                labelText: 'New Category Name',
                hintText: 'Enter category to add...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              controller: descriptionInputController,
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Describe this category for better auto-categorization',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop()),
        FilledButton(
          onPressed: () {
            final name = categoryInputController.text.trim();
            final description = descriptionInputController.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop({'name': name, 'description': description});
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// CP: CategoryCard widget for consistent styling with entries list
class CategoryCard extends StatelessWidget {
  final Category category;
  final String displayName;
  final bool isNone;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CategoryCard({
    super.key,
    required this.category,
    required this.displayName,
    required this.isNone,
    this.onEdit,
    this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // CP: Get category color for visual consistency with entries list
    final categoryColor =
        isNone
            ? Colors.grey.withOpacity(0.3)
            : CategoryColors.getColorForCategory(category.name).withValues(alpha: 0.3);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor, width: 2.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            // CP: Category color indicator dot
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: categoryColor.withValues(alpha: 0.8), shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),

            // CP: Category info section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isNone ? Colors.grey : null,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (category.description.isNotEmpty && !isNone) ...[
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // CP: Action buttons (only for non-None categories)
            if (!isNone) ...[
              const SizedBox(width: 8),
              _ActionButton(icon: Icons.edit_outlined, tooltip: 'Rename Category', onPressed: onEdit),
              const SizedBox(width: 4),
              _ActionButton(
                icon: Icons.delete_outline,
                tooltip: 'Delete Category',
                color: Colors.redAccent[100],
                onPressed: onDelete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// CP: Custom action button for consistent styling
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color? color;
  final VoidCallback? onPressed;

  const _ActionButton({required this.icon, required this.tooltip, this.color, this.onPressed});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, size: 20, color: color ?? Colors.grey[600]),
        ),
      ),
    );
  }
}
