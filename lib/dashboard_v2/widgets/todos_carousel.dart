import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/dashboard_v2/cubit/todo_cubit.dart';
import 'package:myapp/dashboard_v2/cubit/todos_carousel_cubit.dart';
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
              // CC: Filter out todos that are being removed
              final activeTodos = todoState.activeTodos.where((todo) {
                final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                return !carouselState.completedTodoIds.contains(todoId);
              }).toList();

              // CC: Include completed todos that are still showing (within 3 seconds)
              final recentlyCompleted = todoState.completedTodos.where((todo) {
                final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                return carouselState.completedTodoIds.contains(todoId);
              }).toList();

              // CC: Combine and sort by timestamp
              final allTodos = [...activeTodos, ...recentlyCompleted];
              allTodos.sort((a, b) => b.timestamp.compareTo(a.timestamp));

              final displayTodos = allTodos.take(maxTodos).toList();

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
    final todoCubit = context.read<TodoCubit>();
    final carouselCubit = context.read<TodosCarouselCubit>();

    // CC: Toggle completion in TodoCubit
    todoCubit.toggleTodoCompletion(todo);

    // CC: Handle carousel state for animation
    carouselCubit.handleTodoCompletion(todo, !todo.isCompleted);
  }
}
