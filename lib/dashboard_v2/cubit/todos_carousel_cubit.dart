import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/entry.dart';

part 'todos_carousel_state.dart';

class TodosCarouselCubit extends Cubit<TodosCarouselState> {
  final Map<String, Timer> _removalTimers = {};

  TodosCarouselCubit() : super(const TodosCarouselState());

  void handleTodoCompletion(Entry todo, bool isCompleting) {
    final todoId = todo.timestamp.millisecondsSinceEpoch.toString();

    if (isCompleting) {
      // CC: Mark todo as completed and schedule removal
      _scheduleRemoval(todoId);
    } else {
      // CC: Cancel removal if todo is being uncompleted
      _cancelRemoval(todoId);
    }
  }

  void _scheduleRemoval(String todoId) {
    // CC: Add to completed IDs immediately
    final newCompletedIds = Set<String>.from(state.completedTodoIds)..add(todoId);
    final newRemovalSchedule = Map<String, DateTime>.from(state.removalSchedule)
      ..[todoId] = DateTime.now().add(const Duration(seconds: 3));

    emit(state.copyWith(
      completedTodoIds: newCompletedIds,
      removalSchedule: newRemovalSchedule,
    ));

    // CC: Schedule removal after 3 seconds
    _removalTimers[todoId] = Timer(const Duration(seconds: 3), () {
      _removeCompletedTodo(todoId);
    });
  }

  void _cancelRemoval(String todoId) {
    // CC: Cancel the timer if it exists
    _removalTimers[todoId]?.cancel();
    _removalTimers.remove(todoId);

    // CC: Remove from completed IDs and removal schedule
    final newCompletedIds = Set<String>.from(state.completedTodoIds)..remove(todoId);
    final newRemovalSchedule = Map<String, DateTime>.from(state.removalSchedule)..remove(todoId);

    emit(state.copyWith(
      completedTodoIds: newCompletedIds,
      removalSchedule: newRemovalSchedule,
    ));
  }

  void _removeCompletedTodo(String todoId) {
    // CC: Remove from completed IDs and removal schedule
    final newCompletedIds = Set<String>.from(state.completedTodoIds)..remove(todoId);
    final newRemovalSchedule = Map<String, DateTime>.from(state.removalSchedule)..remove(todoId);

    emit(state.copyWith(
      completedTodoIds: newCompletedIds,
      removalSchedule: newRemovalSchedule,
    ));

    _removalTimers.remove(todoId);
  }

  @override
  Future<void> close() {
    // CC: Cancel all timers
    for (final timer in _removalTimers.values) {
      timer.cancel();
    }
    _removalTimers.clear();
    return super.close();
  }
}