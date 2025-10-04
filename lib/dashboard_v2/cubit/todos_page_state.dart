part of 'todos_page_cubit.dart';

class TodosPageState extends Equatable {
  final Set<String> completedTodoIds;
  final Map<String, int> originalPositions; // CC: Track original position of todos

  const TodosPageState({
    this.completedTodoIds = const {},
    this.originalPositions = const {}, // CC: Initialize empty map
  });

  TodosPageState copyWith({
    Set<String>? completedTodoIds,
    Map<String, int>? originalPositions,
  }) {
    return TodosPageState(
      completedTodoIds: completedTodoIds ?? this.completedTodoIds,
      originalPositions: originalPositions ?? this.originalPositions,
    );
  }

  @override
  List<Object?> get props => [completedTodoIds, originalPositions];
}
