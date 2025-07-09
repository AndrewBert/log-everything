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
          final cubit = context.read<CategoryEntriesCubit>();
          
          // CC: Update category name and description
          cubit.updateCategory(name, description);
          
          // CC: Update the color
          await CategoryColors.setColorForCategory(name, color);
          
          // CC: If the name changed, also update the color mapping
          if (name != category.name) {
            await CategoryColors.setColorForCategory(category.name, color);
          }
          
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