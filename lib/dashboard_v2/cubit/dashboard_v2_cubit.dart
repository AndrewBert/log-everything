import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/dashboard_v2/model/insight.dart';
import 'package:get_it/get_it.dart';

part 'dashboard_v2_state.dart';

class DashboardV2Cubit extends Cubit<DashboardV2State> {
  final EntryRepository _entryRepository;
  final AiService _aiService = GetIt.instance<AiService>();
  StreamSubscription<List<Entry>>? _entriesSubscription;

  DashboardV2Cubit({
    required EntryRepository entryRepository,
  }) : _entryRepository = entryRepository,
       super(const DashboardV2State()) {
    // CC: Subscribe to entries stream
    _entriesSubscription = _entryRepository.entriesStream.listen(_onEntriesUpdated);
  }

  void loadEntries() {
    emit(state.copyWith(isLoading: true));

    final entries = _entryRepository.currentEntries;
    emit(
      state.copyWith(
        entries: entries,
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

    // CC: Skip if entry already has insight
    if (entry.insight != null) {
      return;
    }

    // CC: Only set isGeneratingInsight if this is for the selected entry
    if (index == state.selectedCarouselIndex) {
      emit(state.copyWith(isGeneratingInsight: true));
    }

    try {
      final entryId = entry.timestamp.millisecondsSinceEpoch.toString();
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

  void _onEntriesUpdated(List<Entry> entries) {
    // CC: Check if we have new entries
    final hasNewEntries = entries.length > state.entries.length;

    // CC: Update state with new entries from stream
    emit(
      state.copyWith(
        entries: entries,
        // CC: Reset selected index if it's out of bounds
        selectedCarouselIndex: state.selectedCarouselIndex >= entries.length ? 0 : state.selectedCarouselIndex,
      ),
    );

    // CC: If we have new entries, trigger insight generation for the most recent one
    if (hasNewEntries && entries.isNotEmpty) {
      // CC: Select the first entry (most recent) to trigger insight generation
      selectCarouselEntry(0);
      // CC: Also generate insights for other recent entries
      _generateInsightsForRecentEntries();
    }
  }

  @override
  Future<void> close() {
    _entriesSubscription?.cancel();
    return super.close();
  }
}
