import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/dashboard_v2/cubit/category_entries_cubit.dart';
import 'package:myapp/dashboard_v2/widgets/category_form.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/utils/category_colors.dart';

class EditCategoryPage extends StatelessWidget {
  final Category category;

  const EditCategoryPage({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    // CC: Use color from category model, fallback to CategoryColors for migration
    final currentColor = category.color ?? CategoryColors.getColorForCategory(category.name);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Category'),
        elevation: 0,
        actions: [
          // CP: Archive/Unarchive button
          IconButton(
            icon: Icon(
              category.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
            ),
            onPressed: () async {
              // CP: Show confirmation dialog
              final shouldArchive = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: Text(
                      category.isArchived ? 'Unarchive Category' : 'Archive Category',
                    ),
                    content: Text(
                      category.isArchived
                          ? 'Are you sure you want to unarchive "${category.name}"?'
                          : 'Are you sure you want to archive "${category.name}"? It will be hidden from the main category list.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text(category.isArchived ? 'Unarchive' : 'Archive'),
                      ),
                    ],
                  );
                },
              );

              if (shouldArchive == true && context.mounted) {
                final cubit = context.read<CategoryEntriesCubit>();
                await cubit.toggleArchive();

                if (context.mounted) {
                  // CP: Pop twice to go back to category list
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        category.isArchived
                            ? 'Category "${category.name}" unarchived'
                            : 'Category "${category.name}" archived',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            tooltip: category.isArchived ? 'Unarchive Category' : 'Archive Category',
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              // CC: Show confirmation dialog
              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Delete Category'),
                    content: Text(
                      'Are you sure you want to delete "${category.name}"? All entries in this category will be moved to "Misc".',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(dialogContext).colorScheme.error,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  );
                },
              );

              if (shouldDelete == true && context.mounted) {
                final cubit = context.read<CategoryEntriesCubit>();
                await cubit.deleteCategory();

                if (context.mounted) {
                  // CC: Pop twice to go back to category list
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Category "${category.name}" deleted'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            tooltip: 'Delete Category',
          ),
        ],
      ),
      body: CategoryForm(
        initialName: category.name,
        initialDescription: category.description,
        initialColor: currentColor,
        submitButtonText: 'Save Changes',
        onSubmit: (name, description, color) async {
          final cubit = context.read<CategoryEntriesCubit>();

          // CC: Update category with all changes at once (name, description, color)
          await cubit.updateCategory(name, description, color: color);

          if (context.mounted) {
            Navigator.of(context).pop();

            // CC: Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Category updated successfully'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
