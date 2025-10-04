import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/cubit/todo_cubit.dart';
import 'package:myapp/dashboard_v2/cubit/todos_page_cubit.dart';
import 'package:myapp/dashboard_v2/pages/entry_details_page.dart';
import 'package:myapp/dashboard_v2/widgets/rectangular_todo_card.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => TodoCubit(
            entryRepository: GetIt.instance<EntryRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => TodosPageCubit(),
        ),
      ],
      child: Scaffold(
        key: todosPageKey,
        appBar: AppBar(
          title: const Text('Todos'),
          elevation: 0,
        ),
        body: BlocBuilder<TodoCubit, TodoState>(
          builder: (context, todoState) {
            return BlocBuilder<TodosPageCubit, TodosPageState>(
              builder: (context, pageState) {
                if (todoState.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (todoState.activeTodos.isEmpty && todoState.completedTodos.isEmpty) {
                  return Center(
                    child: Text(
                      'No todos yet',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  );
                }

                // CC: Combine active todos and recently completed todos
                // Include todos that are either active OR recently completed (within 3 seconds)
                final allVisibleTodos = [
                  ...todoState.activeTodos,
                  ...todoState.completedTodos.where((todo) {
                    final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                    return pageState.completedTodoIds.contains(todoId);
                  }),
                ]..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // CC: Keep original sort order

                return CustomScrollView(
                  slivers: [
                    // CC: Active todos (including recently completed ones still animating)
                    if (allVisibleTodos.isNotEmpty) ...[
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Text(
                            'Active',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final todo = allVisibleTodos[index];
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
                                          cachedInsight: todo.getCurrentInsight() != null
                                              ? Insight(
                                                  id: todo.timestamp.millisecondsSinceEpoch.toString(),
                                                  type: InsightType.summary,
                                                  title: 'Insight',
                                                  content: todo.getCurrentInsight()!.content,
                                                  generatedAt: todo.getCurrentInsight()!.generatedAt,
                                                )
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            childCount: allVisibleTodos.length,
                          ),
                        ),
                      ),
                    ],

                    // CC: Completed section header - only show if there are completed todos not currently animating
                    Builder(
                      builder: (context) {
                        final nonAnimatingCompletedTodos = todoState.completedTodos.where((todo) {
                          final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                          return !pageState.completedTodoIds.contains(todoId);
                        }).toList();

                        if (nonAnimatingCompletedTodos.isEmpty) {
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        }

                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Completed',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                                TextButton(
                                  key: showCompletedButtonKey,
                                  onPressed: () {
                                    context.read<TodoCubit>().toggleShowCompleted();
                                  },
                                  child: Text(
                                    todoState.showCompleted ? 'Hide' : 'Show',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // CC: Completed todos (shown/hidden based on state)
                    if (todoState.showCompleted) ...[
                      Builder(
                        builder: (context) {
                          // CC: Filter out todos that are still animating in the active section
                          final visibleCompletedTodos = todoState.completedTodos.where((todo) {
                            final todoId = todo.timestamp.millisecondsSinceEpoch.toString();
                            return !pageState.completedTodoIds.contains(todoId);
                          }).toList();

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final todo = visibleCompletedTodos[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: RectangularTodoCard(
                                      todo: todo,
                                      onCheckboxTap: () {
                                        _handleTodoCompletion(context, todo);
                                      },
                                    ),
                                  );
                                },
                                childCount: visibleCompletedTodos.length,
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    // CC: Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 24),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _handleTodoCompletion(BuildContext context, Entry todo) {
    final todoCubit = context.read<TodoCubit>();
    final pagesCubit = context.read<TodosPageCubit>();

    // CC: Toggle completion in TodoCubit
    todoCubit.toggleTodoCompletion(todo);

    // CC: Handle page state for animation
    pagesCubit.handleTodoCompletion(todo, !todo.isCompleted);
  }
}
