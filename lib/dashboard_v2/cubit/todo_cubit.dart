import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/entry.dart';

part 'todo_state.dart';

class TodoCubit extends Cubit<TodoState> {
  final EntryRepository _entryRepository;
  StreamSubscription<List<Entry>>? _entriesSubscription;

  TodoCubit({
    required EntryRepository entryRepository,
  }) : _entryRepository = entryRepository,
       super(const TodoState()) {
    // CC: Subscribe to entries stream
    _entriesSubscription = _entryRepository.entriesStream.listen(_onEntriesUpdated);
    // CC: Load initial todos
    _loadTodos();
  }

  void _loadTodos() {
    emit(state.copyWith(isLoading: true));
    _updateTodosFromEntries(_entryRepository.currentEntries);
  }

  void _onEntriesUpdated(List<Entry> entries) {
    _updateTodosFromEntries(entries);
  }

  void _updateTodosFromEntries(List<Entry> entries) {
    // CC: Debug logging
    print('[TodoCubit] _updateTodosFromEntries called with ${entries.length} entries');

    // CC: Filter entries where isTask is true
    final allTodos = entries.where((entry) => entry.isTask).toList();
    print('  - Found ${allTodos.length} todos (isTask=true)');

    // CC: Separate active and completed todos
    final activeTodos = allTodos.where((todo) => !todo.isCompleted).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // CC: Newest first

    print('  - Active todos: ${activeTodos.length}');
    for (var i = 0; i < activeTodos.length && i < 3; i++) {
      print('    ${i + 1}. ${activeTodos[i].text.substring(0, activeTodos[i].text.length.clamp(0, 30))}...');
    }

    final completedTodos = allTodos.where((todo) => todo.isCompleted).toList()
      ..sort((a, b) {
        // CC: Sort by completedAt if available, otherwise fall back to timestamp
        final aCompletedAt = a.completedAt ?? a.timestamp;
        final bCompletedAt = b.completedAt ?? b.timestamp;
        print(
          '    Comparing: ${a.text.substring(0, a.text.length.clamp(0, 20))}... (${a.completedAt}) vs ${b.text.substring(0, b.text.length.clamp(0, 20))}... (${b.completedAt})',
        );
        return bCompletedAt.compareTo(aCompletedAt); // CC: Recently completed first
      });

    print('  - Completed todos: ${completedTodos.length}');
    for (var i = 0; i < completedTodos.length && i < 3; i++) {
      print(
        '    ${i + 1}. ${completedTodos[i].text.substring(0, completedTodos[i].text.length.clamp(0, 30))}... (completedAt: ${completedTodos[i].completedAt})',
      );
    }

    emit(
      state.copyWith(
        activeTodos: activeTodos,
        completedTodos: completedTodos,
        isLoading: false,
      ),
    );

    print('[TodoCubit] _updateTodosFromEntries finished - emitted new state');
  }

  Future<void> toggleTodoCompletion(Entry todo) async {
    // CC: Debug logging
    print('[TodoCubit] toggleTodoCompletion called');
    print('  - Original todo text: ${todo.text.substring(0, todo.text.length.clamp(0, 50))}...');
    print('  - Original isCompleted: ${todo.isCompleted}');
    print('  - Original completedAt: ${todo.completedAt}');

    // CC: Toggle completion status
    final updatedTodo = todo.toggleCompletion();
    print('  - Updated isCompleted: ${updatedTodo.isCompleted}');
    print('  - Updated completedAt: ${updatedTodo.completedAt}');

    print('[TodoCubit] Calling _entryRepository.updateEntry');
    await _entryRepository.updateEntry(todo, updatedTodo);
    print('[TodoCubit] toggleTodoCompletion finished');
  }

  void toggleShowCompleted() {
    emit(state.copyWith(showCompleted: !state.showCompleted));
  }

  @override
  Future<void> close() {
    _entriesSubscription?.cancel();
    return super.close();
  }
}
