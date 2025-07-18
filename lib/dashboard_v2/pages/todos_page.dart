import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/dashboard_v2/cubit/todo_cubit.dart';
import 'package:myapp/dashboard_v2/widgets/rectangular_todo_card.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/utils/dashboard_v2_keys.dart';

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (context) => TodoCubit(
        entryRepository: GetIt.instance<EntryRepository>(),
      ),
      child: Scaffold(
        key: todosPageKey,
        appBar: AppBar(
          title: const Text('Todos'),
          elevation: 0,
        ),
        body: BlocBuilder<TodoCubit, TodoState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (state.activeTodos.isEmpty && state.completedTodos.isEmpty) {
              return Center(
                child: Text(
                  'No todos yet',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              );
            }

            return CustomScrollView(
              slivers: [
                // CC: Active todos
                if (state.activeTodos.isNotEmpty) ...[
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
                          final todo = state.activeTodos[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: RectangularTodoCard(
                              todo: todo,
                              onCheckboxTap: () {
                                context.read<TodoCubit>().toggleTodoCompletion(todo);
                              },
                            ),
                          );
                        },
                        childCount: state.activeTodos.length,
                      ),
                    ),
                  ),
                ],
                
                // CC: Completed section header
                if (state.completedTodos.isNotEmpty) ...[
                  SliverPadding(
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
                              state.showCompleted ? 'Hide' : 'Show',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // CC: Completed todos (shown/hidden based on state)
                  if (state.showCompleted)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final todo = state.completedTodos[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: RectangularTodoCard(
                                todo: todo,
                                onCheckboxTap: () {
                                  context.read<TodoCubit>().toggleTodoCompletion(todo);
                                },
                              ),
                            );
                          },
                          childCount: state.completedTodos.length,
                        ),
                      ),
                    ),
                ],
                
                // CC: Bottom padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}