import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/onboarding_cubit.dart';
import '../model/model.dart';

class CategoriesSetupStep extends StatelessWidget {
  const CategoriesSetupStep({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Choose Your Categories',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Select categories that match your lifestyle. The AI will use these to organize your entries automatically. You can always add more later!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600], height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                'Choose Categories by Theme',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _buildGroupedCategoryChips(context, state),
              const SizedBox(height: 32),
              _buildAddCustomCategory(context),
              const SizedBox(height: 24),
              if (state.selectedCategories.isNotEmpty) ...[
                Text(
                  'Selected Categories (${state.selectedCategories.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _buildSelectedCategories(context, state),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupedCategoryChips(BuildContext context, OnboardingState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          state.categoryGroups.map((group) {
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CP: Group header with icon and title
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: group.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: group.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(group.icon, size: 18, color: group.color),
                        const SizedBox(width: 8),
                        Text(
                          group.title,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: group.color),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // CP: Category chips for this group
                  Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children:
                        group.categories.map((category) {
                          final isSelected = state.selectedCategories.contains(category);

                          return FilterChip(
                            label: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? group.color : Colors.grey[700],
                                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              context.read<OnboardingCubit>().toggleCategorySelection(category);
                            },
                            selectedColor: group.color.withValues(alpha: 0.15),
                            backgroundColor: Colors.transparent,
                            checkmarkColor: group.color,
                            side: BorderSide(
                              color: isSelected ? group.color : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          );
                        }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildAddCustomCategory(BuildContext context) {
    final controller = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Add Custom Category',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Reading, Gaming, Cooking...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      context.read<OnboardingCubit>().addCustomCategory(value.trim());
                      controller.clear();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) {
                    context.read<OnboardingCubit>().addCustomCategory(value);
                    controller.clear();
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedCategories(BuildContext context, OnboardingState state) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children:
          state.selectedCategories.map((category) {
            // CP: Find the group this category belongs to for consistent coloring
            final group = state.categoryGroups.firstWhere(
              (g) => g.categories.contains(category),
              orElse: () => state.categoryGroups.last, // CP: Default to misc group
            );

            return Chip(
              label: Text(category, style: TextStyle(color: group.color, fontWeight: FontWeight.w500)),
              backgroundColor: group.color.withValues(alpha: 0.1),
              side: BorderSide(color: group.color, width: 1.5),
              deleteIcon: Icon(Icons.close, size: 18, color: group.color),
              onDeleted: () {
                context.read<OnboardingCubit>().toggleCategorySelection(category);
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            );
          }).toList(),
    );
  }
}
