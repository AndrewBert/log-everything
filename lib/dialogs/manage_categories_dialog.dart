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
  final _descriptionInputController = TextEditingController();

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
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(
          maxWidth: 480,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CP: Modern header with gradient background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                    theme.colorScheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Categories',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Organize and customize your categories',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // CP: Modern add button with gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          final entryCubit = context.read<EntryCubit>();
                          final rootNavigator = Navigator.of(context, rootNavigator: true);

                          HapticFeedback.lightImpact();
                          final result = await showDialog<Map<String, String>?>(
                            context: context,
                            builder: (dialogContext) => const AddCategoryDialog(),
                          );

                          if (!mounted) return;
                          if (result != null && result['name'] != null) {
                            entryCubit.addCustomCategoryWithDescription(
                              result['name']!,
                              result['description'] ?? '',
                            );
                            ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                              SnackBar(
                                content: Text('Category "${result['name']}" added'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add,
                                color: theme.colorScheme.onPrimary,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // CP: Categories list with modern card design
            Flexible(
              child: BlocBuilder<EntryCubit, EntryState>(
                builder: (context, state) {
                  if (state.categories.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  final List<String> displayCategories = List<String>.from(
                    state.categories.map((cat) => categoryDisplayName(cat.name)),
                  );
                  displayCategories.remove('None');
                  final sortedCategories = displayCategories.reversed.toList();
                  sortedCategories.add('None');

                  return ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: sortedCategories.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final category = sortedCategories[index];
                      final bool isNone = category == 'None';
                      final Category catObj = state.categories.firstWhere(
                        (cat) => categoryDisplayName(cat.name) == category,
                        orElse: () => Category(name: category),
                      );

                      return _ModernCategoryCard(
                        category: category,
                        categoryObj: catObj,
                        isNone: isNone,
                        onEdit: () async {
                          final result = await widget.onShowEditCategoryDialog(
                            context,
                            categoryBackendValue(category),
                          );
                          if (!mounted) return;

                          if (result != null && result.isNotEmpty && result != category) {
                            HapticFeedback.mediumImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Category renamed to "${categoryDisplayName(result)}"'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        onDelete: () async {
                          final confirmed = await widget.onShowDeleteCategoryConfirmationDialog(
                            context,
                            categoryBackendValue(category),
                          );
                          if (!mounted) return;

                          if (confirmed) {
                            HapticFeedback.mediumImpact();
                            context.read<EntryCubit>().deleteCategory(categoryBackendValue(category));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Category "${categoryDisplayName(category)}" deleted'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // CP: Modern footer with subtle background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.5),
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.category_outlined,
                size: 48,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Categories Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the Add button to create your first category',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// CP: Modern category card widget with enhanced design and inline editing for both name and description
class _ModernCategoryCard extends StatefulWidget {
  final String category;
  final Category categoryObj;
  final bool isNone;
  final VoidCallback onEdit; // CP: Will be removed once inline editing is complete
  final VoidCallback onDelete;

  const _ModernCategoryCard({
    required this.category,
    required this.categoryObj,
    required this.isNone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ModernCategoryCard> createState() => _ModernCategoryCardState();
}

class _ModernCategoryCardState extends State<_ModernCategoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;
  bool _isEditingDescription = false;
  bool _isEditingName = false; // CP: Add name editing state
  late TextEditingController _descriptionController;
  late TextEditingController _nameController; // CP: Add name controller
  late FocusNode _descriptionFocusNode;
  late FocusNode _nameFocusNode; // CP: Add name focus node

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _elevationAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOutCubic),
    );

    _descriptionController = TextEditingController(text: widget.categoryObj.description);
    _nameController = TextEditingController(text: widget.category); // CP: Initialize name controller
    _descriptionFocusNode = FocusNode();
    _nameFocusNode = FocusNode(); // CP: Initialize name focus node
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _descriptionController.dispose();
    _nameController.dispose(); // CP: Dispose name controller
    _descriptionFocusNode.dispose();
    _nameFocusNode.dispose(); // CP: Dispose name focus node
    super.dispose();
  }

  void _startEditingDescription() {
    setState(() {
      _isEditingDescription = true;
    });
    // CP: Focus the text field after the widget rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _descriptionFocusNode.requestFocus();
    });
    HapticFeedback.lightImpact();
  }

  void _saveDescription() {
    final newDescription = _descriptionController.text.trim();

    // CP: Add safety check for mounted state
    if (!mounted) return;

    // CP: Update the category description via the cubit
    context.read<EntryCubit>().updateCategoryDescription(
      categoryBackendValue(widget.category),
      newDescription,
    );

    if (!mounted) return;

    setState(() {
      _isEditingDescription = false;
    });

    HapticFeedback.mediumImpact();

    // CP: Show feedback to user with mounted check
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Description updated for "${widget.category}"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _cancelEditing() {
    if (!mounted) return;
    _descriptionController.text = widget.categoryObj.description; // CP: Reset to original
    setState(() {
      _isEditingDescription = false;
    });
  }

  // CP: Add inline name editing methods
  void _startEditingName() {
    if (!mounted) return;
    setState(() {
      _isEditingName = true;
    });
    // CP: Focus the text field after the widget rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _nameFocusNode.canRequestFocus) {
        _nameFocusNode.requestFocus();
        _nameController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _nameController.text.length,
        ); // CP: Select all text
      }
    });
    HapticFeedback.lightImpact();
  }

  void _saveName() {
    final newName = _nameController.text.trim();

    // CP: Validate the new name
    if (newName.isEmpty) {
      _cancelNameEditing();
      return;
    }

    // CP: Add safety check for mounted state
    if (!mounted) return;

    // CP: Check if name already exists (but allow same name to update description)
    final existingCategories = context.read<EntryCubit>().state.categories;
    final isNameChanged = newName != widget.category;
    final nameExists = existingCategories.any(
      (cat) => categoryDisplayName(cat.name).toLowerCase() == newName.toLowerCase(),
    );

    if (isNameChanged && nameExists) {
      // CP: Show error feedback with mounted check
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Category "$newName" already exists'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // CP: Update the category name via the cubit
    context.read<EntryCubit>().renameCategory(
      categoryBackendValue(widget.category),
      categoryBackendValue(newName),
      description: widget.categoryObj.description, // CP: Keep existing description
    );

    if (!mounted) return;

    setState(() {
      _isEditingName = false;
    });

    HapticFeedback.mediumImpact();

    // CP: Show feedback to user with mounted check
    if (mounted && isNameChanged) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Category renamed to "$newName"'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _cancelNameEditing() {
    if (!mounted) return;
    _nameController.text = widget.category; // CP: Reset to original
    setState(() {
      _isEditingName = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = CategoryColors.getColorForCategory(widget.categoryObj.name);

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) {
              _hoverController.forward();
            },
            onExit: (_) {
              _hoverController.reverse();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  stops: const [0.015, 0.015],
                  colors: [
                    widget.isNone ? Colors.grey.withValues(alpha: 0.4) : categoryColor.withValues(alpha: 0.8),
                    theme.cardColor,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.isNone ? Colors.black.withValues(alpha: 0.03) : categoryColor.withValues(alpha: 0.15),
                    blurRadius: 4.0 + _elevationAnimation.value,
                    spreadRadius: _elevationAnimation.value * 0.2,
                    offset: Offset(0, 2 + _elevationAnimation.value * 0.5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    // CP: Top row with inline editable category name and only delete button
                    Row(
                      children: [
                        // CP: Inline editable category name chip
                        Expanded(
                          child: _InlineEditableCategoryName(
                            categoryName: widget.category,
                            categoryColor: categoryColor,
                            isNone: widget.isNone,
                            isEditing: _isEditingName,
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            onStartEditing:
                                widget.isNone ? null : _startEditingName, // CP: Disable editing for None category
                            onSave: _saveName,
                            onCancel: _cancelNameEditing,
                          ),
                        ),

                        const SizedBox(width: 16),

                        // CP: Only delete button - edit functionality is now fully inline
                        if (!widget.isNone) ...[
                          _ActionButton(
                            icon: Icons.delete_outline,
                            tooltip: 'Delete Category',
                            color: Colors.red,
                            onPressed: widget.onDelete,
                          ),
                        ],
                      ],
                    ),

                    // CP: Description section with inline editing (unchanged)
                    if (!widget.isNone) ...[
                      const SizedBox(height: 12),
                      _InlineEditableDescription(
                        description: widget.categoryObj.description,
                        isEditing: _isEditingDescription,
                        controller: _descriptionController,
                        focusNode: _descriptionFocusNode,
                        onStartEditing: _startEditingDescription,
                        onSave: _saveDescription,
                        onCancel: _cancelEditing,
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Default category for uncategorized entries',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// CP: Inline editable category name widget
class _InlineEditableCategoryName extends StatelessWidget {
  final String categoryName;
  final Color categoryColor;
  final bool isNone;
  final bool isEditing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback? onStartEditing;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _InlineEditableCategoryName({
    required this.categoryName,
    required this.categoryColor,
    required this.isNone,
    required this.isEditing,
    required this.controller,
    required this.focusNode,
    required this.onStartEditing,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CP: Inline text field for editing category name - fix width constraints
          SizedBox(
            width: double.infinity, // CP: Ensure proper width constraints
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Category name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: theme.colorScheme.surface.withValues(alpha: 0.8),
              ),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              onSubmitted: (_) => onSave(),
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(height: 8),
          // CP: Fix button layout to prevent overflow - use Wrap instead of Row
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: [
              TextButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // CP: Reduced padding
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // CP: Reduced padding
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // CP: Display mode with tap to edit (unless it's the None category)
      return GestureDetector(
        onTap: onStartEditing,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isNone ? Colors.grey.withValues(alpha: 0.15) : categoryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isNone ? Colors.grey.withValues(alpha: 0.3) : categoryColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  categoryName,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isNone ? Colors.grey[700] : CategoryColors.getTextColorForCategory(categoryName),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // CP: Show edit hint for non-None categories
              if (!isNone && onStartEditing != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: CategoryColors.getTextColorForCategory(categoryName).withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }
}

// CP: Inline editable description widget
class _InlineEditableDescription extends StatelessWidget {
  final String description;
  final bool isEditing;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onStartEditing;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _InlineEditableDescription({
    required this.description,
    required this.isEditing,
    required this.controller,
    required this.focusNode,
    required this.onStartEditing,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isEditing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CP: Inline text field for editing
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 3,
            minLines: 2,
            decoration: InputDecoration(
              hintText: 'Describe this category for better auto-categorization',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
              filled: true,
              fillColor: theme.colorScheme.surface.withValues(alpha: 0.8),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.3,
            ),
            onSubmitted: (_) => onSave(),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 8),
          // CP: Action buttons for save/cancel
          Row(
            children: [
              TextButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('Cancel'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // CP: Display mode with tap to edit
      return GestureDetector(
        onTap: onStartEditing,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) ...[
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.3,
                  ),
                ),
              ] else ...[
                Text(
                  'Tap to add description...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tap to edit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
}

// CP: Modern action button with enhanced styling
class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _controller.forward();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _controller.reverse();
              HapticFeedback.lightImpact();
              widget.onPressed();
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _controller.reverse();
            },
            child: Tooltip(
              message: widget.tooltip,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _isPressed ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.color.withValues(alpha: _isPressed ? 0.4 : 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: widget.color,
                ),
              ),
            ),
          ),
        );
      },
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
                hintText: 'Describe this category for better auto-categorization',
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
