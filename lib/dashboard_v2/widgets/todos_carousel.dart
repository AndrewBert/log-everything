import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/dashboard_v2/cubit/todo_cubit.dart';
import 'package:myapp/dashboard_v2/widgets/rectangular_todo_card.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class TodosCarousel extends StatefulWidget {
  final VoidCallback? onHeaderTap;
  final int maxTodos;

  const TodosCarousel({
    super.key,
    this.onHeaderTap,
    this.maxTodos = 3,
  });

  @override
  State<TodosCarousel> createState() => _TodosCarouselState();
}

class _TodosCarouselState extends State<TodosCarousel> {
  final Set<String> _completedTodoIds = {};
  final Map<String, Timer> _removalTimers = {};

  void _handleTodoCompletion(Entry todo) {
    final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
    
    context.read<TodoCubit>().toggleTodoCompletion(todo);
    
    if (!todo.isCompleted) {
      // CC: Todo is being marked as completed
      setState(() {
        _completedTodoIds.add(todoId);
      });
      
      // CC: Remove after 3 seconds
      _removalTimers[todoId] = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _completedTodoIds.remove(todoId);
          });
          _removalTimers.remove(todoId);
        }
      });
    } else {
      // CC: Todo is being uncompleted
      _removalTimers[todoId]?.cancel();
      _removalTimers.remove(todoId);
      setState(() {
        _completedTodoIds.remove(todoId);
      });
    }
  }

  @override
  void dispose() {
    // CC: Cancel all timers
    for (final timer in _removalTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<TodoCubit, TodoState>(
      builder: (context, state) {
        // CC: Filter out todos that are being removed
        final activeTodos = state.activeTodos.where((todo) {
          final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
          return !_completedTodoIds.contains(todoId);
        }).toList();
        
        // CC: Include completed todos that are still showing (within 3 seconds)
        final recentlyCompleted = state.completedTodos.where((todo) {
          final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
          return _completedTodoIds.contains(todoId);
        }).toList();
        
        // CC: Combine and sort by timestamp
        final allTodos = [...activeTodos, ...recentlyCompleted];
        allTodos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
        final displayTodos = allTodos.take(widget.maxTodos).toList();
        
        if (displayTodos.isEmpty && state.activeTodos.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CC: Header
            InkWell(
              onTap: widget.onHeaderTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Todos',
                      style: theme.textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        if (state.activeTodos.length > widget.maxTodos)
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
                              '+${state.activeTodos.length - widget.maxTodos}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (state.activeTodos.length > widget.maxTodos)
                          const SizedBox(width: 8),
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
                        _handleTodoCompletion(todo);
                      },
                      onTap: widget.onHeaderTap,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}