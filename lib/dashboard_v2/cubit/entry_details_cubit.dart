import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:get_it/get_it.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/utils/logger.dart';

part 'entry_details_state.dart';

class EntryDetailsCubit extends Cubit<EntryDetailsState> {
  final EntryRepository _entryRepository;
  final AiService _aiService = GetIt.instance<AiService>();
  final TextEditingController textController = TextEditingController();
  final FocusNode textFocusNode = FocusNode();
  Timer? _autoSaveTimer;
  Timer? _saveStatusResetTimer;

  EntryDetailsCubit({
    required EntryRepository entryRepository,
  }) : _entryRepository = entryRepository,
       super(const EntryDetailsState()) {
    // Listen for focus changes to trigger save on focus loss
    textFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!textFocusNode.hasFocus && state.isEditing) {
      finalizeEdit();
    }
  }

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
        originalEntryText: state.entry!.text,
      ),
    );

    AppLogger.info('[EntryDetailsCubit] startEditing - captured originalEntryText: "${state.entry!.text}"');

    // CP: Request focus after state update
    WidgetsBinding.instance.addPostFrameCallback((_) {
      textFocusNode.requestFocus();
    });
  }

  void updateEditedText(String text) {
    emit(state.copyWith(editedText: text));

    // Cancel existing auto-save timer
    _autoSaveTimer?.cancel();

    // Start new auto-save timer (500ms debounce)
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _autoSaveText();
    });
  }

  Future<void> _autoSaveText() async {
    if (state.entry == null || state.editedText == null) return;

    final originalText = state.entry!.text;
    final newText = state.editedText!.trim();

    // Don't save if text hasn't changed
    if (originalText == newText) return;

    emit(state.copyWith(saveStatus: SaveStatus.saving));

    try {
      final updatedEntry = state.entry!.copyWith(text: newText);
      // Skip AI regeneration for auto-save
      await _entryRepository.updateEntry(state.entry!, updatedEntry, skipAiRegeneration: true);

      emit(
        state.copyWith(
          entry: updatedEntry,
          saveStatus: SaveStatus.saved,
        ),
      );

      // Reset save status to idle after 2 seconds
      _saveStatusResetTimer?.cancel();
      _saveStatusResetTimer = Timer(const Duration(seconds: 2), () {
        if (!isClosed) {
          emit(state.copyWith(saveStatus: SaveStatus.idle));
        }
      });
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            saveStatus: SaveStatus.idle,
            errorMessage: 'Failed to auto-save changes',
          ),
        );
      }
    }
  }

  Future<void> finalizeEdit() async {
    AppLogger.info('[EntryDetailsCubit] finalizeEdit called');
    AppLogger.info('[EntryDetailsCubit] state.entry.text: ${state.entry?.text}');
    AppLogger.info('[EntryDetailsCubit] state.isEditing: ${state.isEditing}');
    AppLogger.info('[EntryDetailsCubit] state.editedText: ${state.editedText}');
    AppLogger.info('[EntryDetailsCubit] state.originalEntryText: ${state.originalEntryText}');

    if (state.entry == null) {
      AppLogger.warn('[EntryDetailsCubit] finalizeEdit - entry is null, returning');
      return;
    }

    // Cancel any pending auto-save
    _autoSaveTimer?.cancel();

    final originalText = state.originalEntryText ?? state.entry!.text;
    final newText = state.editedText?.trim() ?? state.entry!.text;

    AppLogger.info('[EntryDetailsCubit] originalText (from originalEntryText): "$originalText"');
    AppLogger.info('[EntryDetailsCubit] newText (from editedText): "$newText"');
    AppLogger.info('[EntryDetailsCubit] text changed: ${originalText != newText}');

    // If text hasn't changed, just exit edit mode
    if (originalText == newText) {
      AppLogger.info('[EntryDetailsCubit] Text unchanged, exiting edit mode without AI regeneration');
      emit(
        state.copyWith(
          isEditing: false,
          clearEditedText: true,
          clearOriginalEntryText: true,
        ),
      );
      return;
    }

    try {
      AppLogger.info('[EntryDetailsCubit] Text changed! Saving updated entry to repository');
      // Mark entry as generating insight before updating
      final updatedEntry = state.entry!.copyWith(text: newText, isGeneratingInsight: true);
      // Full save with AI regeneration
      await _entryRepository.updateEntry(state.entry!, updatedEntry);
      AppLogger.info('[EntryDetailsCubit] Entry saved with isGeneratingInsight=true');

      emit(
        state.copyWith(
          entry: updatedEntry,
          isEditing: false,
          clearEditedText: true,
          clearOriginalEntryText: true,
        ),
      );

      // Regenerate insight when text changes
      AppLogger.info('[EntryDetailsCubit] Calling _generatePrimaryInsight for updated entry');
      _generatePrimaryInsight(updatedEntry);
    } catch (e) {
      AppLogger.error('[EntryDetailsCubit] Error in finalizeEdit', error: e);
      if (!isClosed) {
        emit(
          state.copyWith(
            errorMessage: 'Failed to save changes',
            isEditing: false,
            clearEditedText: true,
            clearOriginalEntryText: true,
          ),
        );
      }
    }
  }

  Future<void> saveAndExitEditMode() async {
    await finalizeEdit();
  }

  void cancelEditing() {
    AppLogger.info('[EntryDetailsCubit] cancelEditing - clearing edit state');
    textController.clear();
    emit(
      state.copyWith(
        isEditing: false,
        clearEditedText: true,
        clearOriginalEntryText: true,
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
    AppLogger.info('[EntryDetailsCubit] _generatePrimaryInsight called for entry: "${entry.text.substring(0, entry.text.length > 50 ? 50 : entry.text.length)}..."');
    AppLogger.info('[EntryDetailsCubit] Setting isRegeneratingInsight to true');

    emit(state.copyWith(isRegeneratingInsight: true));

    try {
      final entryId = entry.timestamp.millisecondsSinceEpoch.toString();
      AppLogger.info('[EntryDetailsCubit] Calling AI service to generate insights for entryId: $entryId');

      final comprehensiveInsight = await _aiService.generateEntryInsights(entry.text, entryId);
      AppLogger.info('[EntryDetailsCubit] AI service returned comprehensiveInsight');

      // Re-fetch the current entry to avoid overwriting user changes made during insight generation
      final currentEntries = _entryRepository.currentEntries;
      final currentEntry = currentEntries.firstWhere(
        (e) => e.timestamp == entry.timestamp,
        orElse: () => entry,
      );

      AppLogger.info('[EntryDetailsCubit] Saving insight to repository for entry: $entryId');
      // Update entry with insight AND clear generating flag, preserving any user changes
      final updatedEntry = currentEntry.copyWith(
        insight: comprehensiveInsight,
        isGeneratingInsight: false,
      );
      // Skip AI regeneration (vector store sync) for insight-only updates
      await _entryRepository.updateEntry(currentEntry, updatedEntry, skipAiRegeneration: true);

      AppLogger.info('[EntryDetailsCubit] Insight saved successfully to repository with isGeneratingInsight=false');

      // Use the priority system to get the most relevant insight
      final primaryInsight = comprehensiveInsight.getPrimaryInsight();
      AppLogger.info('[EntryDetailsCubit] Primary insight extracted: ${primaryInsight != null ? primaryInsight.type : "null"}');

      if (primaryInsight != null) {
        AppLogger.info('[EntryDetailsCubit] Emitting primary insight: ${primaryInsight.content.substring(0, primaryInsight.content.length > 100 ? 100 : primaryInsight.content.length)}...');
        emit(
          state.copyWith(
            entry: updatedEntry,
            primaryInsight: primaryInsight,
            isRegeneratingInsight: false,
          ),
        );
      } else {
        AppLogger.warn('[EntryDetailsCubit] No primary insight found, setting isRegeneratingInsight to false');
        if (!isClosed) {
          emit(
            state.copyWith(
              entry: updatedEntry,
              isRegeneratingInsight: false,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('[EntryDetailsCubit] Error generating primary insight', error: e, stackTrace: stackTrace);

      // Clear generating flag even on error
      try {
        final currentEntries = _entryRepository.currentEntries;
        final currentEntry = currentEntries.firstWhere(
          (e) => e.timestamp == entry.timestamp,
          orElse: () => entry,
        );
        final updatedEntry = currentEntry.copyWith(isGeneratingInsight: false);
        await _entryRepository.updateEntry(currentEntry, updatedEntry, skipAiRegeneration: true);
        AppLogger.info('[EntryDetailsCubit] Cleared isGeneratingInsight flag after error');
      } catch (updateError) {
        AppLogger.error('[EntryDetailsCubit] Failed to clear isGeneratingInsight flag', error: updateError);
      }

      // CC: Check if cubit is still active before emitting
      if (!isClosed) {
        emit(state.copyWith(isRegeneratingInsight: false));
      }
    }
  }

  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    _saveStatusResetTimer?.cancel();
    textController.dispose();
    textFocusNode.dispose();
    return super.close();
  }
}
