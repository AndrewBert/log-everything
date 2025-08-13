import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/dashboard_v2/cubit/todo_cubit.dart';
import 'package:myapp/dashboard_v2/cubit/todos_carousel_cubit.dart';
import 'package:myapp/dashboard_v2/pages/entry_details_page.dart';
import 'package:myapp/dashboard_v2/widgets/rectangular_todo_card.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class TodosCarousel extends StatelessWidget {
  final VoidCallback? onHeaderTap;
  final int maxTodos;

  const TodosCarousel({
    super.key,
    this.onHeaderTap,
    this.maxTodos = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => TodosCarouselCubit(),
      child: BlocBuilder<TodoCubit, TodoState>(
        builder: (context, todoState) {
          return BlocBuilder<TodosCarouselCubit, TodosCarouselState>(
            builder: (context, carouselState) {
              print('🔍 TodosCarousel rebuild:');
              print('  - todoState.activeTodos: ${todoState.activeTodos.length}');
              print('  - todoState.completedTodos: ${todoState.completedTodos.length}');
              print('  - carouselState.completedTodoIds: ${carouselState.completedTodoIds}');

              // CC: Filter out todos that are being removed (but keep if still transitioning)
              final activeTodos = todoState.activeTodos.where((todo) {
                final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                // Keep active todos that are NOT in completedTodoIds
                final shouldInclude = !carouselState.completedTodoIds.contains(todoId);
                print(
                  '  - Active todo ${todo.text.substring(0, 20.clamp(0, todo.text.length))}... (id: $todoId) included: $shouldInclude',
                );
                return shouldInclude;
              }).toList();

              // CC: Include completed todos that are still showing (within 3 seconds)
              final recentlyCompleted = todoState.completedTodos.where((todo) {
                final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                final shouldInclude = carouselState.completedTodoIds.contains(todoId);
                print(
                  '  - Completed todo ${todo.text.substring(0, 20.clamp(0, todo.text.length))}... (id: $todoId) included: $shouldInclude',
                );
                return shouldInclude;
              }).toList();

              // CC: Also check activeTodos for items that are in completedTodoIds (transitioning state)
              final transitioningTodos = todoState.activeTodos.where((todo) {
                final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                final isTransitioning = carouselState.completedTodoIds.contains(todoId);
                if (isTransitioning) {
                  print(
                    '  - TRANSITIONING todo ${todo.text.substring(0, 20.clamp(0, todo.text.length))}... (id: $todoId)',
                  );
                }
                return isTransitioning;
              }).toList();

              print('  - Filtered activeTodos: ${activeTodos.length}');
              print('  - Filtered recentlyCompleted: ${recentlyCompleted.length}');
              print('  - Transitioning todos: ${transitioningTodos.length}');

              // CC: Combine all three lists and sort by timestamp
              final allTodos = [...activeTodos, ...recentlyCompleted, ...transitioningTodos];
              allTodos.sort((a, b) => b.timestamp.compareTo(a.timestamp));

              final displayTodos = allTodos.take(maxTodos).toList();
              print('  - Final displayTodos: ${displayTodos.length}');
              print('---');

              if (displayTodos.isEmpty && todoState.activeTodos.isEmpty) {
                return const SizedBox.shrink();
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CC: Header
                  InkWell(
                    onTap: onHeaderTap,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TODOS',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          Row(
                            children: [
                              if (todoState.activeTodos.length > maxTodos)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '+${todoState.activeTodos.length - maxTodos}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              if (todoState.activeTodos.length > maxTodos) const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 20,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // CC: Todo list
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      key: todosCarouselKey,
                      children: displayTodos.map((todo) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RectangularTodoCard(
                            todo: todo,
                            onCheckboxTap: () {
                              _handleTodoCompletion(context, todo);
                            },
                            onEntryTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => EntryDetailsPage(
                                    entry: todo,
                                    cachedInsight: todo.insight?.getPrimaryInsight(),
                                  ),
                                ),
                              );
                            },
                            onTap: onHeaderTap,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _handleTodoCompletion(BuildContext context, Entry todo) {
    print('🎯 _handleTodoCompletion called:');
    print('  - Todo: ${todo.text.substring(0, 20.clamp(0, todo.text.length))}...');
    print('  - Current isCompleted: ${todo.isCompleted}');
    print('  - Will set to: ${!todo.isCompleted}');

    final todoCubit = context.read<TodoCubit>();
    final carouselCubit = context.read<TodosCarouselCubit>();

    // CC: Toggle completion in TodoCubit
    print('  - Calling todoCubit.toggleTodoCompletion...');
    todoCubit.toggleTodoCompletion(todo);

    // CC: Handle carousel state for animation
    print('  - Calling carouselCubit.handleTodoCompletion...');
    carouselCubit.handleTodoCompletion(todo, !todo.isCompleted);
  }
}
