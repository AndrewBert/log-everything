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

    // CC: Debug logging
    print('[TodosPageCubit] handleTodoCompletion called');
    print('  - Todo text: ${todo.text.substring(0, todo.text.length.clamp(0, 50))}...');
    print('  - Todo ID (UUID): $todoId');
    print('  - isCompleting: $isCompleting');
    print('  - Current completedTodoIds: ${state.completedTodoIds}');

    if (isCompleting) {
      // CC: Cancel any existing timer for this todo
      if (_removalTimers.containsKey(todoId)) {
        print('  - Cancelling existing timer for todo $todoId');
        _removalTimers[todoId]?.cancel();
        _removalTimers.remove(todoId);
      }

      // CC: Add to completed set
      final newCompletedIds = Set<String>.from(state.completedTodoIds)..add(todoId);
      print('  - Adding to completedTodoIds: $todoId');
      print('  - New completedTodoIds: $newCompletedIds');
      emit(state.copyWith(completedTodoIds: newCompletedIds));

      // CC: Schedule removal after 3 seconds
      print('  - Scheduling removal timer (3 seconds)');
      _removalTimers[todoId] = Timer(const Duration(seconds: 3), () {
        print('[TodosPageCubit] Timer fired for todo $todoId');
        final updatedIds = Set<String>.from(state.completedTodoIds)..remove(todoId);
        print('  - Removing from completedTodoIds: $todoId');
        print('  - Updated completedTodoIds: $updatedIds');
        emit(state.copyWith(completedTodoIds: updatedIds));
        _removalTimers.remove(todoId);
      });
    } else {
      // CC: If uncompleting, cancel timer and remove from completed set
      if (_removalTimers.containsKey(todoId)) {
        print('  - Cancelling timer for uncompleting todo $todoId');
        _removalTimers[todoId]?.cancel();
        _removalTimers.remove(todoId);
      }

      final updatedIds = Set<String>.from(state.completedTodoIds)..remove(todoId);
      print('  - Removing from completedTodoIds (uncompleting): $todoId');
      print('  - Updated completedTodoIds: $updatedIds');
      emit(state.copyWith(completedTodoIds: updatedIds));
    }

    print('[TodosPageCubit] handleTodoCompletion finished');
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
