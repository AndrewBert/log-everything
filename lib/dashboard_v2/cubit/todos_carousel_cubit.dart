import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/entry.dart';

part 'todos_carousel_state.dart';

class TodosCarouselCubit extends Cubit<TodosCarouselState> {
  final Map<String, Timer> _transitionTimers = {};

  TodosCarouselCubit() : super(const TodosCarouselState());

  void handleTodoCompletion(Entry todo, bool isCompleting) {
    final todoId = todo.id;

    // CC: Cancel any existing timer for this todo
    _transitionTimers[todoId]?.cancel();
    _transitionTimers.remove(todoId);

    // CC: Update the todo's transition state
    final newStates = Map<String, TodoTransitionState>.from(state.todoStates);

    if (isCompleting) {
      // CC: Mark as completing, then after delay mark as completed
      newStates[todoId] = TodoTransitionState.completing;
      emit(state.copyWith(todoStates: newStates));

      // CC: After 3 seconds, mark as fully completed (remove from display)
      _transitionTimers[todoId] = Timer(const Duration(seconds: 3), () {
        final updatedStates = Map<String, TodoTransitionState>.from(state.todoStates);
        updatedStates[todoId] = TodoTransitionState.completed;
        emit(state.copyWith(todoStates: updatedStates));
        _transitionTimers.remove(todoId);
      });
    } else {
      // CC: Mark as uncompleting, then after delay mark as active
      newStates[todoId] = TodoTransitionState.uncompleting;
      emit(state.copyWith(todoStates: newStates));

      // CC: After 1 second, mark as fully active (normal display)
      _transitionTimers[todoId] = Timer(const Duration(seconds: 1), () {
        final updatedStates = Map<String, TodoTransitionState>.from(state.todoStates);
        updatedStates[todoId] = TodoTransitionState.active;
        emit(state.copyWith(todoStates: updatedStates));
        _transitionTimers.remove(todoId);
      });
    }
  }

  @override
  Future<void> close() {
    // CC: Cancel all timers
    for (final timer in _transitionTimers.values) {
      timer.cancel();
    }
    _transitionTimers.clear();
    return super.close();
  }
}
