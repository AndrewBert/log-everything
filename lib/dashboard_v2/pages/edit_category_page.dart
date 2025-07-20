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
