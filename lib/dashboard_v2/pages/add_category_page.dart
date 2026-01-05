import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/entry/cubit/entry_cubit.dart';
import 'package:myapp/dashboard_v2/widgets/category_form.dart';

class AddCategoryPage extends StatelessWidget {
  const AddCategoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Category'),
        elevation: 0,
      ),
      body: CategoryForm(
        submitButtonText: 'Create Category',
        onSubmit: (name, description, color) async {
          // CC: Create the category with color in the Category model
          await context.read<EntryCubit>().addCustomCategoryWithDescription(
            name,
            description,
            color: color,
          );

          if (context.mounted) {
            // CP: Return the created category name for callers that need it
            Navigator.of(context).pop(name);

            // CC: Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Category "$name" created'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}
