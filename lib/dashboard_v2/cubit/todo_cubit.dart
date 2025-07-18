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
  })  : _entryRepository = entryRepository,
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
    // CC: Filter entries where isTask is true
    final allTodos = entries.where((entry) => entry.isTask).toList();
    
    // CC: Separate active and completed todos
    final activeTodos = allTodos
        .where((todo) => !todo.isCompleted)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // CC: Newest first
    
    final completedTodos = allTodos
        .where((todo) => todo.isCompleted)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // CC: Newest first

    emit(
      state.copyWith(
        activeTodos: activeTodos,
        completedTodos: completedTodos,
        isLoading: false,
      ),
    );
  }

  Future<void> toggleTodoCompletion(Entry todo) async {
    // CC: Toggle completion status
    final updatedTodo = todo.toggleCompletion();
    await _entryRepository.updateEntry(todo, updatedTodo);
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