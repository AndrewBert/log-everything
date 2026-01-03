part of 'todos_carousel_cubit.dart';

enum TodoTransitionState {
  active, // Normal active todo
  highlighting, // Newly added todo, showing highlight animation
  completing, // Just marked complete, animating
  completed, // Fully completed, removed from display
  uncompleting, // Just marked active, transitioning back
}

class TodosCarouselState extends Equatable {
  final Map<String, TodoTransitionState> todoStates;

  const TodosCarouselState({
    this.todoStates = const {},
  });

  TodosCarouselState copyWith({
    Map<String, TodoTransitionState>? todoStates,
  }) {
    return TodosCarouselState(
      todoStates: todoStates ?? this.todoStates,
    );
  }

  @override
  List<Object?> get props => [
    todoStates,
  ];
}
