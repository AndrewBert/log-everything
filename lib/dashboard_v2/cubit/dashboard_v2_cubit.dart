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

  DashboardV2Cubit({
    required EntryRepository entryRepository,
  }) : _entryRepository = entryRepository,
       super(const DashboardV2State());

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

    // CC: The first entry's insight (if any) will be shown via the getter
    print('DEBUG: loadEntries - First entry has insight: ${entries.isNotEmpty ? entries[0].insight != null : false}');
    print('DEBUG: loadEntries - isGeneratingInsight: ${state.isGeneratingInsight}');

    // CC: Generate insights for the most recent 3 entries without insights
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
      print('DEBUG: _generateInsightForEntry - Entry at index $index already has insight, skipping');
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

  // CC: Generate insights for up to 3 recent entries that don't have insights
  void _generateInsightsForRecentEntries() async {
    final entries = state.entries;
    int insightsGenerated = 0;
    
    for (int i = 0; i < entries.length && insightsGenerated < 3; i++) {
      if (entries[i].insight == null) {
        // Don't await - let them generate in parallel
        _generateInsightForEntry(i);
        insightsGenerated++;
      } else {
      }
    }
  }
}
