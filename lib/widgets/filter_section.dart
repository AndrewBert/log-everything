import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entry/cubit/entry_cubit.dart';

// Helper to map backend 'Misc' to frontend 'None' and vice versa
String categoryDisplayName(String category) =>
    category == 'Misc' ? 'None' : category;
String categoryBackendValue(String displayName) =>
    displayName == 'None' ? 'Misc' : displayName;

class FilterSection extends StatelessWidget {
  const FilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 4.0,
        bottom: 4.0,
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          BlocBuilder<EntryCubit, EntryState>(
            builder: (context, state) {
              // Place 'None' first, then all other categories sorted
              final sortedCategories =
                  List<String>.from(state.categories)
                    ..remove('Misc')
                    ..sort();
              final dropdownCategories = [
                'All Categories',
                'None',
                ...sortedCategories.map(categoryDisplayName),
              ];

              // Ensure the current value exists in the list
              String currentDisplayValue = categoryDisplayName(
                state.filterCategory ?? 'All Categories',
              );
              if (!dropdownCategories.contains(currentDisplayValue)) {
                currentDisplayValue = 'All Categories';
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  // Replace deprecated surfaceVariant
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest // Use replacement
                      // Replace deprecated withOpacity
                      .withAlpha((255 * 0.4).round()),
                  borderRadius: BorderRadius.circular(20.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentDisplayValue,
                    icon: const Icon(Icons.filter_list_alt, size: 20),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    items:
                        dropdownCategories.map((String category) {
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(
                                fontWeight:
                                    category == currentDisplayValue
                                        ? FontWeight
                                            .bold // Make selected bold
                                        : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue == null) return;

                      final cubit = context.read<EntryCubit>();
                      final currentFilter = state.filterCategory;

                      if (newValue == 'All Categories') {
                        // If 'All Categories' is selected, clear the filter
                        if (currentFilter != null) {
                          cubit.setFilter(null);
                        }
                      } else {
                        // If a specific category is selected, set the filter
                        final backendValue = categoryBackendValue(newValue);
                        if (currentFilter != backendValue) {
                          cubit.setFilter(backendValue);
                        }
                      }
                    },
                    isDense: true,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
