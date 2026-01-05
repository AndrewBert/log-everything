import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:myapp/dashboard_v2/pages/add_category_page.dart';

/// Shows a bottom sheet for selecting or creating a category.
/// Returns the selected category name, or null if dismissed.
Future<String?> showCategoryPickerBottomSheet({
  required BuildContext context,
  String? currentCategory,
  String title = 'Select Category',
}) async {
  final categories = GetIt.instance<EntryRepository>().currentCategories;

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          // CP: Header with title and close button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
          // CP: Category list with "Create new" at top
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: categories.length + 1, // +1 for "Create new" option
              itemBuilder: (context, index) {
                // CP: First item is "Create new category"
                if (index == 0) {
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.add,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      'Create new category',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      // CP: Navigate to add category page
                      final result = await Navigator.of(sheetContext).push<String>(
                        MaterialPageRoute(
                          builder: (_) => const AddCategoryPage(),
                        ),
                      );
                      // CP: If a category was created, return it
                      if (sheetContext.mounted && result != null) {
                        Navigator.of(sheetContext).pop(result);
                      }
                    },
                  );
                }

                // CP: Regular category items (offset by 1 due to "Create new")
                final category = categories[index - 1];
                final isSelected = category.name == currentCategory;
                final categoryColor = _getCategoryColor(category);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? categoryColor : categoryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.onPrimary,
                            size: 18,
                          )
                        : null,
                  ),
                  title: Text(
                    category.displayName,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  subtitle: category.description.isNotEmpty
                      ? Text(
                          category.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(sheetContext).pop(category.name);
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

/// Get the display color for a category
Color _getCategoryColor(Category category) {
  // CP: Use category's own color if set, otherwise fall back to CategoryColors utility
  return category.color ?? CategoryColors.getColorForCategory(category.name);
}
