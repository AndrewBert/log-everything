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
