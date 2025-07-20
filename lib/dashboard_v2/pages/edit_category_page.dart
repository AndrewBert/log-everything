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
    final currentColor = CategoryColors.getColorForCategory(category.name);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Category'),
        elevation: 0,
      ),
      body: CategoryForm(
        initialName: category.name,
        initialDescription: category.description,
        initialColor: currentColor,
        submitButtonText: 'Save Changes',
        onSubmit: (name, description, color) async {
          print('[EditCategoryPage] SUBMIT STARTED');
          print('[EditCategoryPage] Original category: ${category.name}');
          print('[EditCategoryPage] New name: $name');
          print('[EditCategoryPage] New description: $description');
          print('[EditCategoryPage] New color: $color');
          
          final cubit = context.read<CategoryEntriesCubit>();

          // CC: Update the color first (before category name changes)
          print('[EditCategoryPage] Setting color for category "$name" to $color');
          await CategoryColors.setColorForCategory(name, color);
          print('[EditCategoryPage] Color set successfully');

          // CC: If the name changed, remove the old color mapping
          if (name != category.name) {
            print('[EditCategoryPage] Name changed, removing old color mapping for "${category.name}"');
            await CategoryColors.removeColorForCategory(category.name);
            print('[EditCategoryPage] Old color mapping removed');
          } else {
            print('[EditCategoryPage] Name unchanged, keeping same color mapping');
          }

          // CC: Update category name and description
          print('[EditCategoryPage] Updating category via cubit');
          await cubit.updateCategory(name, description);
          print('[EditCategoryPage] Category updated via cubit');

          // CC: Force UI refresh by reloading the cubit state to pick up color changes
          print('[EditCategoryPage] Triggering cubit refresh');
          cubit.refreshState();
          print('[EditCategoryPage] Cubit refresh completed');

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
          
          print('[EditCategoryPage] SUBMIT COMPLETED');
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
