part of 'todos_page_cubit.dart';

class TodosPageState extends Equatable {
  final Set<String> completedTodoIds;

  const TodosPageState({
    this.completedTodoIds = const {},
  });

  TodosPageState copyWith({
    Set<String>? completedTodoIds,
  }) {
    return TodosPageState(
      completedTodoIds: completedTodoIds ?? this.completedTodoIds,
    );
  }

  @override
  List<Object?> get props => [completedTodoIds];
}