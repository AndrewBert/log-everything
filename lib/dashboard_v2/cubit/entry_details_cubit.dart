import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';

part 'entry_details_state.dart';

class EntryDetailsCubit extends Cubit<EntryDetailsState> {
  final EntryRepository _entryRepository;
  final AiService _aiService = GetIt.instance<AiService>();
  final TextEditingController textController = TextEditingController();
  final FocusNode textFocusNode = FocusNode();

  EntryDetailsCubit({
    required EntryRepository entryRepository,
  }) : _entryRepository = entryRepository,
       super(const EntryDetailsState());

  void loadEntry(Entry entry, {Insight? cachedInsight}) {
    emit(
      state.copyWith(
        entry: entry,
        primaryInsight: cachedInsight,
        clearErrorMessage: true,
      ),
    );

    // CP: If no cached insight, generate one
    if (cachedInsight == null && entry.insight != null) {
      // Use the priority system to get the best insight
      final primaryInsight = entry.insight!.getPrimaryInsight();
      if (primaryInsight != null) {
        emit(state.copyWith(primaryInsight: primaryInsight));
      }
    } else if (cachedInsight == null) {
      _generatePrimaryInsight(entry);
    }
  }

  void startEditing() {
    if (state.entry == null) return;

    textController.text = state.entry!.text;
    emit(
      state.copyWith(
        isEditing: true,
        editedText: state.entry!.text,
      ),
    );

    // CP: Request focus after state update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      textFocusNode.requestFocus();
    });
  }

  void updateEditedText(String text) {
    emit(state.copyWith(editedText: text));
  }

  Future<void> saveAndExitEditMode() async {
    if (state.entry == null || state.editedText == null) return;

    final originalText = state.entry!.text;
    final newText = state.editedText!.trim();

    // CP: Don't save if text hasn't changed
    if (originalText == newText) {
      cancelEditing();
      return;
    }

    emit(state.copyWith(isSaving: true));

    try {
      final updatedEntry = state.entry!.copyWith(text: newText);
      await _entryRepository.updateEntry(state.entry!, updatedEntry);

      emit(
        state.copyWith(
          entry: updatedEntry,
          isEditing: false,
          isSaving: false,
          clearEditedText: true,
        ),
      );

      // CP: Always regenerate insight when text changes
      _generatePrimaryInsight(updatedEntry);
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Failed to save changes',
        ),
      );
    }
  }

  void cancelEditing() {
    textController.clear();
    emit(
      state.copyWith(
        isEditing: false,
        clearEditedText: true,
      ),
    );
  }

  Future<void> updateCategory(String newCategory) async {
    if (state.entry == null) return;

    emit(state.copyWith(isLoading: true));

    try {
      final updatedEntry = state.entry!.copyWith(category: newCategory);
      await _entryRepository.updateEntry(state.entry!, updatedEntry);

      emit(
        state.copyWith(
          entry: updatedEntry,
          isLoading: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to update category',
        ),
      );
    }
  }

  Future<void> toggleTaskCompletion() async {
    if (state.entry == null || !state.entry!.isTask) return;

    try {
      final updatedEntry = state.entry!.toggleCompletion();
      await _entryRepository.updateEntry(state.entry!, updatedEntry);

      emit(state.copyWith(entry: updatedEntry));
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to update task status',
        ),
      );
    }
  }

  Future<void> deleteEntry() async {
    if (state.entry == null) return;

    emit(state.copyWith(isLoading: true));

    try {
      await _entryRepository.deleteEntry(state.entry!);
      // CP: Navigation will be handled by the page
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to delete entry',
        ),
      );
    }
  }

  Future<void> _generatePrimaryInsight(Entry entry) async {
    emit(state.copyWith(isRegeneratingInsight: true));

    try {
      final entryId = entry.timestamp.millisecondsSinceEpoch.toString();
      final comprehensiveInsight = await _aiService.generateEntryInsights(entry.text, entryId);

      // CC: Check if cubit is still active before emitting
      if (isClosed) return;

      // Use the priority system to get the most relevant insight
      final primaryInsight = comprehensiveInsight.getPrimaryInsight();

      if (primaryInsight != null) {
        emit(
          state.copyWith(
            primaryInsight: primaryInsight,
            isRegeneratingInsight: false,
          ),
        );
      } else {
        emit(state.copyWith(isRegeneratingInsight: false));
      }
    } catch (e) {
      // CC: Check if cubit is still active before emitting
      if (!isClosed) {
        emit(state.copyWith(isRegeneratingInsight: false));
      }
    }
  }

  @override
  Future<void> close() {
    textController.dispose();
    textFocusNode.dispose();
    return super.close();
  }
}
