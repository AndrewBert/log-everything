import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/category_colors.dart';

// Helper to map backend 'Misc' to frontend 'None' and vice versa
String categoryDisplayName(String category) =>
    category == 'Misc' ? 'None' : category;
String categoryBackendValue(String displayName) =>
    displayName == 'None' ? 'Misc' : displayName;

class FilterSection extends StatelessWidget {
  const FilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      buildWhen:
          (previous, current) =>
              previous.categories != current.categories ||
              previous.filterCategory != current.filterCategory,
      builder: (context, state) {
        final List<String> filterCategories =
            state.categories
                .map((cat) => categoryDisplayName(cat.name))
                .toSet()
                .toList()
              ..remove('None');
        final chips = ['None', ...filterCategories..sort()];

        return Row(
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
                  selectedColor: Colors.grey,
                  labelStyle: TextStyle(
                    color:
                        state.filterCategory == null
                            ? Colors.white
                            : Colors.black87,
                  ),
                  onSelected: (_) => context.read<EntryCubit>().setFilter(null),
                ),
              ),
            ),
            // CP: Scrollable category chips
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(right: 16.0),
                child: Row(
                  children: [
                    for (final category in chips)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: AnimatedScale(
                          scale:
                              state.filterCategory ==
                                      categoryBackendValue(category)
                                  ? 1.05
                                  : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: FilterChip(
                            selected:
                                state.filterCategory ==
                                categoryBackendValue(category),
                            label: Text(category),
                            labelStyle: TextStyle(
                              color:
                                  state.filterCategory ==
                                          categoryBackendValue(category)
                                      ? Colors.white
                                      : Colors.black87,
                            ),
                            backgroundColor: CategoryColors.getColorForCategory(
                              categoryBackendValue(category),
                            ).withValues(alpha: 0.12),
                            selectedColor: CategoryColors.getColorForCategory(
                              categoryBackendValue(category),
                            ),
                            onSelected:
                                (_) => context.read<EntryCubit>().setFilter(
                                  categoryBackendValue(category),
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
