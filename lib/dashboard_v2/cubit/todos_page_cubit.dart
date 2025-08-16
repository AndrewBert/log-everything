import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/entry.dart';

part 'todos_page_state.dart';

class TodosPageCubit extends Cubit<TodosPageState> {
  final Map<String, Timer> _removalTimers = {};

  TodosPageCubit() : super(const TodosPageState());

  void handleTodoCompletion(Entry todo, bool isCompleting) {
    // CC: Use the entry's unique ID
    final todoId = todo.id;

    if (isCompleting) {
      // CC: Cancel any existing timer for this todo
      if (_removalTimers.containsKey(todoId)) {
        _removalTimers[todoId]?.cancel();
        _removalTimers.remove(todoId);
      }

      // CC: Add to completed set
      final newCompletedIds = Set<String>.from(state.completedTodoIds)..add(todoId);
      emit(state.copyWith(completedTodoIds: newCompletedIds));

      // CC: Schedule removal after 3 seconds
      _removalTimers[todoId] = Timer(const Duration(seconds: 3), () {
        final updatedIds = Set<String>.from(state.completedTodoIds)..remove(todoId);
        emit(state.copyWith(completedTodoIds: updatedIds));
        _removalTimers.remove(todoId);
      });
    } else {
      // CC: If uncompleting, cancel timer and remove from completed set
      if (_removalTimers.containsKey(todoId)) {
        _removalTimers[todoId]?.cancel();
        _removalTimers.remove(todoId);
      }

      final updatedIds = Set<String>.from(state.completedTodoIds)..remove(todoId);
      emit(state.copyWith(completedTodoIds: updatedIds));
    }
  }

  @override
  Future<void> close() {
    // CC: Cancel all timers when cubit is closed
    for (final timer in _removalTimers.values) {
      timer.cancel();
    }
    _removalTimers.clear();
    return super.close();
  }
}
