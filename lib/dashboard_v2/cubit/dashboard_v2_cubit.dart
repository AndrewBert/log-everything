import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/entry/category.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:myapp/utils/category_colors.dart';
import 'package:get_it/get_it.dart';

part 'dashboard_v2_state.dart';

class DashboardV2Cubit extends Cubit<DashboardV2State> {
  final EntryRepository _entryRepository;
  final AiService _aiService = GetIt.instance<AiService>();
  StreamSubscription<List<Entry>>? _entriesSubscription;
  // CC: Track entries currently generating insights to prevent duplicates
  final Set<String> _generatingInsights = {};

  DashboardV2Cubit({
    required EntryRepository entryRepository,
  }) : _entryRepository = entryRepository,
       super(const DashboardV2State()) {
    // CC: Subscribe to entries stream (handles entry AND color changes)
    _entriesSubscription = _entryRepository.entriesStream.listen(_onEntriesUpdated);
  }

  void loadEntries() {
    emit(state.copyWith(isLoading: true));

    final entries = _entryRepository.currentEntries;
    final categories = _entryRepository.currentCategories;
    // CC: Filter out todos from the entries list
    final nonTodoEntries = entries.where((entry) => !entry.isTask).toList();
    emit(
      state.copyWith(
        entries: nonTodoEntries,
        categories: categories,
        isLoading: false,
        hasMoreEntries: false, // CC: For now, load all entries at once
      ),
    );

    // CC: Generate insights for the 3 most recent entries if they don't have insights
    _generateInsightsForRecentEntries();
  }

  void selectCarouselEntry(int index) {
    emit(
      state.copyWith(
        selectedCarouselIndex: index,
        // CC: Clear generating flag when switching entries
        isGeneratingInsight: false,
      ),
    );

    // CC: Check if entry already has insight
    if (index < state.entries.length) {
      final entry = state.entries[index];
      if (entry.insight == null) {
        // CC: Generate insight for selected entry
        _generateInsightForEntry(index);
      }
    }
  }

  Future<void> _generateInsightForEntry(int index) async {
    if (index >= state.entries.length) return;

    final entry = state.entries[index];
    final entryId = entry.timestamp.millisecondsSinceEpoch.toString();

    // CC: Skip if entry already has insight or is currently generating
    if (entry.insight != null || _generatingInsights.contains(entryId)) {
      return;
    }

    // CC: Mark entry as generating
    _generatingInsights.add(entryId);

    // CC: Only set isGeneratingInsight if this is for the selected entry
    if (index == state.selectedCarouselIndex) {
      emit(state.copyWith(isGeneratingInsight: true));
    }

    try {
      final comprehensiveInsight = await _aiService.generateEntryInsights(
        entry.text,
        entryId,
        currentDate: DateTime.now(), // CC: Pass current date for temporal context
      );

      // CC: Update entry with insight
      final updatedEntry = entry.copyWith(insight: comprehensiveInsight);
      await _entryRepository.updateEntry(entry, updatedEntry);

      // CC: Update local state with new entries list
      final updatedEntries = _entryRepository.currentEntries;

      // CC: Only update isGeneratingInsight if this was for the selected entry
      emit(
        state.copyWith(
          entries: updatedEntries,
          isGeneratingInsight: index == state.selectedCarouselIndex ? false : null,
        ),
      );
    } catch (e) {
      // CC: Only update isGeneratingInsight if this was for the selected entry
      if (index == state.selectedCarouselIndex) {
        emit(
          state.copyWith(
            isGeneratingInsight: false,
          ),
        );
      }
    } finally {
      // CC: Remove from generating set
      _generatingInsights.remove(entryId);
    }
  }

  // CC: Generate insights for the 3 most recent entries if they don't have insights
  void _generateInsightsForRecentEntries() async {
    final entries = state.entries;

    // CC: Only check the first 3 entries (most recent)
    final entriesToCheck = entries.length < 3 ? entries.length : 3;

    for (int i = 0; i < entriesToCheck; i++) {
      if (entries[i].insight == null) {
        // Don't await - let them generate in parallel
        _generateInsightForEntry(i);
      }
    }
  }

  // CC: Generate insights for entries 1 and 2 (skip entry 0 to avoid duplicate with selectCarouselEntry)
  void _generateInsightsForOtherRecentEntries() async {
    final entries = state.entries;

    // CC: Only check entries 1 and 2 (skip 0 to avoid duplicate generation)
    final entriesToCheck = entries.length < 3 ? entries.length : 3;

    for (int i = 1; i < entriesToCheck; i++) {
      if (entries[i].insight == null) {
        // Don't await - let them generate in parallel
        _generateInsightForEntry(i);
      }
    }
  }

  void _onEntriesUpdated(List<Entry> entries) {
    // CC: Filter out todos from the entries list
    final nonTodoEntries = entries.where((entry) => !entry.isTask).toList();
    final categories = _entryRepository.currentCategories;

    // CC: Check if we have new entries (not just updates to existing ones)
    final hasNewEntries = nonTodoEntries.length > state.entries.length;

    // CC: Check if the newest entry is actually new (no insight yet)
    final newestEntryIsNew = hasNewEntries && nonTodoEntries.isNotEmpty && nonTodoEntries.first.insight == null;

    // CC: Update state with new entries from stream
    emit(
      state.copyWith(
        entries: nonTodoEntries,
        categories: categories,
        // CC: Reset selected index if it's out of bounds
        selectedCarouselIndex: state.selectedCarouselIndex >= nonTodoEntries.length ? 0 : state.selectedCarouselIndex,
      ),
    );

    // CC: Only trigger insight generation for truly new entries
    if (newestEntryIsNew) {
      // CC: Select the first entry (most recent) to trigger insight generation
      selectCarouselEntry(0);
      // CC: Generate insights for other recent entries (skip index 0 to avoid duplicate)
      _generateInsightsForOtherRecentEntries();
    }
  }

  @override
  Future<void> close() {
    _entriesSubscription?.cancel();
    return super.close();
  }
}
