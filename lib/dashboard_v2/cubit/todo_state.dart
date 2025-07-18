part of 'todo_cubit.dart';

class TodoState extends Equatable {
  final List<Entry> activeTodos;
  final List<Entry> completedTodos;
  final bool isLoading;
  final bool showCompleted;

  const TodoState({
    this.activeTodos = const [],
    this.completedTodos = const [],
    this.isLoading = false,
    this.showCompleted = false,
  });

  TodoState copyWith({
    List<Entry>? activeTodos,
    List<Entry>? completedTodos,
    bool? isLoading,
    bool? showCompleted,
  }) {
    return TodoState(
      activeTodos: activeTodos ?? this.activeTodos,
      completedTodos: completedTodos ?? this.completedTodos,
      isLoading: isLoading ?? this.isLoading,
      showCompleted: showCompleted ?? this.showCompleted,
    );
  }

  @override
  List<Object?> get props => [
        activeTodos,
        completedTodos,
        isLoading,
        showCompleted,
      ];
}