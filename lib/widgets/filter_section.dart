import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../entry/cubit/entry_cubit.dart';
import '../utils/logger.dart';

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
              AppLogger.debug(
                '[FilterSection.builder] Building with categories: ${state.categories}',
              );

              final dropdownCategories = [
                'All Categories',
                ...List<String>.from(state.categories)..sort(),
              ];

              // Ensure the current value exists in the list
              String currentDisplayValue =
                  state.filterCategory ?? 'All Categories';
              if (!dropdownCategories.contains(currentDisplayValue)) {
                currentDisplayValue = 'All Categories';
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 0,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withOpacity(0.4),
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
                        if (currentFilter != newValue) {
                          cubit.setFilter(newValue);
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
