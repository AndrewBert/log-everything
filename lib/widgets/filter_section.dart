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
        // CP: Create filter chips list including 'All' and properly formatted categories
        final List<String> filterCategories =
            state.categories
                .map((cat) => categoryDisplayName(cat.name))
                .toSet()
                .toList()
              ..remove('None');
        final chips = ['All', 'None', ...filterCategories..sort()];

        return Container(
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in chips)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      selected:
                          category == 'All'
                              ? state.filterCategory == null
                              : state.filterCategory ==
                                  categoryBackendValue(category),
                      label: Text(
                        category,
                        style: TextStyle(
                          color:
                              (category == 'All'
                                      ? state.filterCategory == null
                                      : state.filterCategory ==
                                          categoryBackendValue(category))
                                  ? Colors.white
                                  : Colors.black87,
                        ),
                      ),
                      backgroundColor:
                          category == 'All'
                              ? Colors.grey.withValues(alpha: 0.12)
                              : CategoryColors.getColorForCategory(
                                categoryBackendValue(category),
                              ).withValues(alpha: 0.12),
                      selectedColor:
                          category == 'All'
                              ? Colors.grey
                              : CategoryColors.getColorForCategory(
                                categoryBackendValue(category),
                              ),
                      onSelected: (_) {
                        final cubit = context.read<EntryCubit>();
                        if (category == 'All') {
                          cubit.setFilter(null);
                        } else {
                          cubit.setFilter(categoryBackendValue(category));
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
