import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/category.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';
import '../utils/widget_keys.dart';
import 'edit_category_dialog.dart';

// Define callback types for clarity
typedef ShowEditCategoryDialogCallback =
    Future<EditCategoryResult?> Function(BuildContext context, String oldCategoryName);
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
                  // CP: Hide 'None' category from the manage categories list
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
                        child: AnimatedCategoryCard(
                          index: index, // CP: Pass index for animation
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
                              final result = await onShowEditCategoryDialog(
                                itemContext,
                                categoryBackendValue(category),
                              );
                              if (!mounted) {
                                return; // CP: Guard context after async gap
                              }

                              // CP: Handle different result operations
                              if (result?.operation == EditCategoryOperation.deleted) {
                                // CP: Handle deletion from edit dialog
                                HapticFeedback.mediumImpact();
                                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                                  SnackBar(content: Text('Category "${categoryDisplayName(category)}" deleted')),
                                );
                              } else if (result?.operation == EditCategoryOperation.renamed &&
                                  result!.newCategoryName != null &&
                                  result.newCategoryName!.isNotEmpty &&
                                  result.newCategoryName != category) {
                                HapticFeedback.mediumImpact();
                                ScaffoldMessenger.of(rootNavigator.context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Category renamed to "${categoryDisplayName(result.newCategoryName!)}"',
                                    ),
                                  ),
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
                    final result = await showDialog<Map<String, Object>?>(
                      context: context,
                      builder: (dialogContext) => const AddCategoryDialog(),
                    );
                    if (!mounted) return; // CP: Guard context after async gap
                    if (result != null && result['name'] != null) {
                      entryCubit.addCustomCategoryWithDescription(
                        result['name']! as String, 
                        (result['description'] as String?) ?? '',
                        isChecklist: (result['isChecklist'] as bool?) ?? false,
                      );
                      ScaffoldMessenger.of(
                        rootNavigator.context,
                      ).showSnackBar(SnackBar(content: Text('Category "${result['name']! as String}" added')));
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Category'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6), width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
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

class AddCategoryDialog extends StatefulWidget {
  const AddCategoryDialog({super.key});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  late final TextEditingController categoryInputController;
  late final TextEditingController descriptionInputController;
  late final FocusNode categoryFocusNode;
  bool _isChecklist = false;

  @override
  void initState() {
    super.initState();
    categoryInputController = TextEditingController();
    descriptionInputController = TextEditingController();
    categoryFocusNode = FocusNode();

    // CP: Request focus when the dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      categoryFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    categoryInputController.dispose();
    descriptionInputController.dispose();
    categoryFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: addCategoryDialog,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              key: addCategoryNameField,
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
              key: addCategoryDescriptionField,
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
          // CP: Checklist toggle
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
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
                  key: addCategoryChecklistToggle,
                  value: _isChecklist,
                  onChanged: (value) => setState(() => _isChecklist = value),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: addCategoryCancelButton,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: addCategoryAddButton,
          onPressed: () {
            final name = categoryInputController.text.trim();
            final description = descriptionInputController.text.trim();
            if (name.isNotEmpty) {
              Navigator.of(context).pop({
                'name': name, 
                'description': description,
                'isChecklist': _isChecklist,
              });
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
            ? Colors.grey.withValues(alpha: 0.3)
            : CategoryColors.getColorForCategory(category.name).withValues(alpha: 0.3);
    final cardContent = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: !isNone && onEdit != null ? onEdit : null, // CP: Make entire card tappable for editing
        child: Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: categoryColor, width: 2.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 3)),
            ],
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
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isNone ? Colors.grey : null,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // CP: Show checklist indicator
                          if (category.isChecklist && !isNone) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.checklist,
                              key: categoryChecklistIconKey(category.name),
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                      if (category.description.isNotEmpty && !isNone) ...[
                        const SizedBox(height: 6),
                        Text(
                          category.description,
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600], height: 1.3),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // CP: Wrap with Dismissible for swipe-to-delete (only for non-None categories)
    if (!isNone && onDelete != null) {
      return Dismissible(
        key: Key('category_${category.name}'),
        direction: DismissDirection.horizontal, // CP: Allow both left and right swipes
        confirmDismiss: (direction) async {
          // CP: Add haptic feedback when swipe is detected
          HapticFeedback.mediumImpact();
          // CP: Show confirmation and handle deletion
          if (onDelete != null) {
            onDelete!();
          }
          // CP: Return false to prevent auto-dismissal since we handle it in the callback
          return false;
        },
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[300]!, Colors.red[500]!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
        secondaryBackground: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[500]!, Colors.red[300]!],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete_outline, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
        child: cardContent,
      );
    }

    return cardContent;
  }
}

// CP: Animated wrapper for category cards with entrance effects
class AnimatedCategoryCard extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedCategoryCard({super.key, required this.child, required this.index});

  @override
  State<AnimatedCategoryCard> createState() => _AnimatedCategoryCardState();
}

class _AnimatedCategoryCardState extends State<AnimatedCategoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);

    // CP: Staggered entrance based on index
    final delay = widget.index * 80; // 80ms delay between each card

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.1), // CP: Subtle slide from below
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(
          delay / 1000.0, // Convert to percentage
          1.0,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Interval(delay / 1000.0, 1.0, curve: Curves.easeOut)));

    _scaleAnimation = Tween<double>(
      begin: 0.95, // CP: Subtle scale effect
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Interval(delay / 1000.0, 1.0, curve: Curves.easeOutBack)));

    // CP: Start animation immediately when widget is created
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

// CP: Expandable text widget with smooth animations for category descriptions
class AnimatedExpandableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int maxLines;

  const AnimatedExpandableText({super.key, required this.text, this.style, this.maxLines = 2});

  @override
  State<AnimatedExpandableText> createState() => _AnimatedExpandableTextState();
}

class _AnimatedExpandableTextState extends State<AnimatedExpandableText> with TickerProviderStateMixin {
  bool _isExpanded = false;
  bool? _hasTextOverflow;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(duration: const Duration(milliseconds: 300), vsync: this);
    _expandAnimation = CurvedAnimation(parent: _expandController, curve: Curves.easeInOutCubic);

    _fadeController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);

    _fadeController.forward();
  }

  @override
  void dispose() {
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_hasTextOverflow == null) {
          final textSpan = TextSpan(text: widget.text, style: widget.style);
          final textPainter = TextPainter(text: textSpan, maxLines: widget.maxLines, textDirection: TextDirection.ltr)
            ..layout(maxWidth: constraints.maxWidth);

          _hasTextOverflow = textPainter.didExceedMaxLines;
        }

        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizeTransition(
                sizeFactor: _expandAnimation,
                axisAlignment: -1.0,
                child: AnimatedCrossFade(
                  firstChild: Text(
                    widget.text,
                    style: widget.style,
                    maxLines: widget.maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  secondChild: Text(widget.text, style: widget.style),
                  crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ),
              if (_hasTextOverflow == true) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: _toggleExpanded,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: _isExpanded ? 0.1 : 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isExpanded ? 'Show less' : 'Show more',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 2),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
