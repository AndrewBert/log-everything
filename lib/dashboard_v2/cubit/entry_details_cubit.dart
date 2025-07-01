import 'dart:convert';

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
  })  : _entryRepository = entryRepository,
        super(const EntryDetailsState());

  void loadEntry(Entry entry, {Insight? cachedSummaryInsight}) {
    emit(state.copyWith(
      entry: entry,
      summaryInsight: cachedSummaryInsight,
      clearErrorMessage: true,
    ));
    
    // CP: If no cached insight, generate one
    if (cachedSummaryInsight == null) {
      _generateSummaryInsight(entry);
    }
  }

  void startEditing() {
    if (state.entry == null) return;
    
    textController.text = state.entry!.text;
    emit(state.copyWith(
      isEditing: true,
      editedText: state.entry!.text,
    ));
    
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
      
      emit(state.copyWith(
        entry: updatedEntry,
        isEditing: false,
        isSaving: false,
        clearEditedText: true,
      ));
      
      // CP: Regenerate insight if text changed significantly
      if ((newText.length - originalText.length).abs() > 10 ||
          _hasSignificantChange(originalText, newText)) {
        _generateSummaryInsight(updatedEntry);
      }
    } catch (e) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save changes',
      ));
    }
  }

  void cancelEditing() {
    textController.clear();
    emit(state.copyWith(
      isEditing: false,
      clearEditedText: true,
    ));
  }

  Future<void> updateCategory(String newCategory) async {
    if (state.entry == null) return;
    
    emit(state.copyWith(isLoading: true));
    
    try {
      final updatedEntry = state.entry!.copyWith(category: newCategory);
      await _entryRepository.updateEntry(state.entry!, updatedEntry);
      
      emit(state.copyWith(
        entry: updatedEntry,
        isLoading: false,
      ));
      
      // CP: Regenerate insight as category change might affect analysis
      _generateSummaryInsight(updatedEntry);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update category',
      ));
    }
  }

  Future<void> toggleTaskCompletion() async {
    if (state.entry == null || !state.entry!.isTask) return;
    
    try {
      final updatedEntry = state.entry!.toggleCompletion();
      await _entryRepository.updateEntry(state.entry!, updatedEntry);
      
      emit(state.copyWith(entry: updatedEntry));
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to update task status',
      ));
    }
  }

  Future<void> deleteEntry() async {
    if (state.entry == null) return;
    
    emit(state.copyWith(isLoading: true));
    
    try {
      await _entryRepository.deleteEntry(state.entry!);
      // CP: Navigation will be handled by the page
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete entry',
      ));
    }
  }

  Future<void> _generateSummaryInsight(Entry entry) async {
    emit(state.copyWith(isRegeneratingInsight: true));
    
    try {
      final response = await _aiService.generateEntryInsights(entry.text);
      final json = _parseJson(response);
      
      if (json != null && json.containsKey('summary')) {
        final summaryInsight = Insight(
          id: '${entry.timestamp.millisecondsSinceEpoch}_summary',
          type: InsightType.summary,
          title: 'Summary',
          content: json['summary'] as String,
          generatedAt: DateTime.now(),
        );
        
        emit(state.copyWith(
          summaryInsight: summaryInsight,
          isRegeneratingInsight: false,
        ));
      } else {
        emit(state.copyWith(isRegeneratingInsight: false));
      }
    } catch (e) {
      emit(state.copyWith(isRegeneratingInsight: false));
    }
  }

  Map<String, dynamic>? _parseJson(String text) {
    try {
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}') + 1;
      if (jsonStart == -1 || jsonEnd == 0) return null;
      
      final jsonStr = text.substring(jsonStart, jsonEnd);
      return Map<String, dynamic>.from(jsonDecode(jsonStr) as Map);
    } catch (_) {
      return null;
    }
  }

  bool _hasSignificantChange(String original, String updated) {
    // CP: Simple heuristic to detect significant changes
    final originalWords = original.split(' ').where((w) => w.isNotEmpty).toSet();
    final updatedWords = updated.split(' ').where((w) => w.isNotEmpty).toSet();
    
    final addedWords = updatedWords.difference(originalWords).length;
    final removedWords = originalWords.difference(updatedWords).length;
    
    return addedWords + removedWords > 5;
  }

  @override
  Future<void> close() {
    textController.dispose();
    textFocusNode.dispose();
    return super.close();
  }
}