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
    // CC: Include all entries (both regular entries and todos)
    emit(
      state.copyWith(
        entries: entries,
        categories: categories,
        isLoading: false,
        hasMoreEntries: false, // CC: For now, load all entries at once
      ),
    );

    // CC: Generate insights for the 3 most recent entries if they don't have insights
    _generateInsightsForRecentEntries();
  }

  void selectCarouselEntry(int index) {
    // CC: Check if new entry needs insight generation
    bool needsInsight = false;
    if (index < state.entries.length) {
      final entry = state.entries[index];
      needsInsight = entry.getCurrentInsight() == null;
    }

    emit(
      state.copyWith(
        selectedCarouselIndex: index,
        // CC: Set loading state immediately if entry needs insight
        isGeneratingInsight: needsInsight,
      ),
    );

    // CC: Generate insight if needed
    if (needsInsight && index < state.entries.length) {
      _generateInsightForEntry(index);
    }
  }

  Future<void> _generateInsightForEntry(int index) async {
    if (index >= state.entries.length) return;

    final entry = state.entries[index];
    final entryId = entry.timestamp.millisecondsSinceEpoch.toString();

    // CC: Skip if entry already has insight (check BOTH formats!) or is currently generating
    if (entry.getCurrentInsight() != null || _generatingInsights.contains(entryId) || entry.isGeneratingInsight) {
      return;
    }

    // CC: Mark entry as generating both in memory and persistently
    _generatingInsights.add(entryId);

    // Mark entry as generating insight and save to repository
    final generatingEntry = entry.copyWith(isGeneratingInsight: true);
    await _entryRepository.updateEntry(entry, generatingEntry, skipAiRegeneration: true);

    // CC: Only set isGeneratingInsight if this is for the selected entry
    if (index == state.selectedCarouselIndex) {
      emit(state.copyWith(isGeneratingInsight: true, entries: _entryRepository.currentEntries));
    }

    try {
      final simpleInsight = await _aiService.generateSimpleInsight(
        entry.text,
        entryId,
        currentDate: DateTime.now(),
      );

      // CC: Re-fetch the current entry to avoid overwriting user changes made during insight generation
      final currentEntries = _entryRepository.currentEntries;
      // CC: Match by timestamp first, then fall back to text matching if timestamps are unique
      final currentEntry = currentEntries.firstWhere(
        (e) => e.timestamp == entry.timestamp,
        orElse: () => entry,
      );

      // CC: Update entry with insight AND clear generating flag, preserving any user changes
      final updatedEntry = currentEntry.copyWith(
        simpleInsight: simpleInsight,
        isGeneratingInsight: false,
      );
      await _entryRepository.updateEntry(currentEntry, updatedEntry, skipAiRegeneration: true);

      // CC: Update local state with new entries list
      final updatedEntries = _entryRepository.currentEntries;

      // CC: Only update isGeneratingInsight if this was for the selected entry
      if (!isClosed) {
        emit(
          state.copyWith(
            entries: updatedEntries,
            isGeneratingInsight: index == state.selectedCarouselIndex ? false : null,
          ),
        );
      }
    } catch (e) {
      // Clear generating flag even on error
      try {
        final currentEntries = _entryRepository.currentEntries;
        final currentEntry = currentEntries.firstWhere(
          (e) => e.timestamp == entry.timestamp,
          orElse: () => entry,
        );
        final updatedEntry = currentEntry.copyWith(isGeneratingInsight: false);
        await _entryRepository.updateEntry(currentEntry, updatedEntry, skipAiRegeneration: true);
      } catch (updateError) {
        // Ignore cleanup errors
      }

      // CC: Only update isGeneratingInsight if this was for the selected entry
      if (index == state.selectedCarouselIndex && !isClosed) {
        emit(
          state.copyWith(
            isGeneratingInsight: false,
            entries: _entryRepository.currentEntries,
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
      if (entries[i].getCurrentInsight() == null) {
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
      if (entries[i].getCurrentInsight() == null) {
        // Don't await - let them generate in parallel
        _generateInsightForEntry(i);
      }
    }
  }

  void _onEntriesUpdated(List<Entry> entries) {
    // CC: Include all entries (both regular entries and todos)
    final categories = _entryRepository.currentCategories;

    // CC: Check if we have new entries (not just updates to existing ones)
    final hasNewEntries = entries.length > state.entries.length;

    // CC: Check if the newest entry is actually new (no insight yet)
    final newestEntryIsNew = hasNewEntries && entries.isNotEmpty && entries.first.getCurrentInsight() == null;

    // CC: Update state with new entries from stream
    emit(
      state.copyWith(
        entries: entries,
        categories: categories,
        // CC: Reset selected index if it's out of bounds
        selectedCarouselIndex: state.selectedCarouselIndex >= entries.length ? 0 : state.selectedCarouselIndex,
      ),
    );

    // CC: Only trigger insight generation for truly new entries
    if (newestEntryIsNew) {
      // CC: Always reset to index 0 when new entry is added for smooth UX
      // Set isGeneratingInsight immediately to prevent white box flash
      emit(
        state.copyWith(
          selectedCarouselIndex: 0,
          isGeneratingInsight: true,
        ),
      );

      // CC: Generate insight for the new entry
      _generateInsightForEntry(0);
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
