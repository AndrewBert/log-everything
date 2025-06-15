import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';

// Helper to map backend 'Misc' to frontend 'None' and vice versa
String categoryDisplayName(String category) => category == 'Misc' ? 'None' : category;
String categoryBackendValue(String displayName) => displayName == 'None' ? 'Misc' : displayName;

class FilterSection extends StatelessWidget {
  const FilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      buildWhen:
          (previous, current) =>
              previous.categories != current.categories ||
              previous.filterCategory != current.filterCategory ||
              previous.recentCategories != current.recentCategories,
      builder: (context, state) {
        // Get all categories in display format
        final List<String> allCategories =
            state.categories.map((cat) => categoryDisplayName(cat.name)).toList()
              ..remove('None')
              ..sort();

        // Convert recent categories to display format
        final recentDisplayCategories = state.recentCategories.map(categoryDisplayName).toList();

        // Filter out recent categories from main list
        final otherCategories =
            ['None', ...allCategories].where((cat) => !recentDisplayCategories.contains(cat)).toList();

        return Container(
          height: 44,
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // CP: Sticky "All" chip
              Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 8.0),
                child: AnimatedScale(
                  scale: state.filterCategory == null ? 1.05 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: FilterChip(
                    selected: state.filterCategory == null,
                    label: const Text('All'),
                    backgroundColor: Colors.grey.withValues(alpha: 0.12),
                    // CP: Use primary color for selectedColor to match app bar 'Log'
                    selectedColor: Theme.of(context).colorScheme.primary,
                    labelStyle: TextStyle(color: state.filterCategory == null ? Colors.white : Colors.black87),
                    onSelected: (_) => context.read<EntryCubit>().setFilter(null),
                  ),
                ),
              ),
              // CP: Scrolling section with recent and other categories
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Row(
                    children: [
                      // CP: Recently used categories
                      if (recentDisplayCategories.isNotEmpty) ...[
                        for (final category in recentDisplayCategories)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4.0),
                            child: _buildChip(context, category, state),
                          ),
                        // CP: Visual separator between recent and other categories
                        if (otherCategories.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Container(height: 24, width: 1, color: Colors.grey.withValues(alpha: 0.2)),
                          ),
                      ],
                      // CP: Other categories
                      for (final category in otherCategories)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: _buildChip(context, category, state),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(BuildContext context, String category, EntryState state) {
    return AnimatedScale(
      scale: state.filterCategory == categoryBackendValue(category) ? 1.05 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: FilterChip(
        selected: state.filterCategory == categoryBackendValue(category),
        label: Text(category),
        backgroundColor: CategoryColors.getColorForCategory(categoryBackendValue(category)).withValues(alpha: 0.12),
        selectedColor: CategoryColors.getColorForCategory(categoryBackendValue(category)),
        labelStyle: TextStyle(
          color: state.filterCategory == categoryBackendValue(category) ? Colors.white : Colors.black87,
        ),
        onSelected: (_) => context.read<EntryCubit>().setFilter(categoryBackendValue(category)),
      ),
    );
  }
}
