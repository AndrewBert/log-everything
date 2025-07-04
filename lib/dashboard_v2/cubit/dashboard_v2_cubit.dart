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
        hasMoreEntries: false, // CP: For now, load all entries at once
        insightsCache: const {}, // CP: Clear old cache to avoid type mismatch
        clearCurrentInsight: true,
      ),
    );

    // CP: Generate insight for the first entry if available
    if (entries.isNotEmpty) {
      _generateInsightForEntry(0);
    }
  }

  void selectCarouselEntry(int index) {
    emit(
      state.copyWith(
        selectedCarouselIndex: index,
        clearCurrentInsight: true,
      ),
    );

    // CP: Generate insight for selected entry
    _generateInsightForEntry(index);
  }

  Future<void> _generateInsightForEntry(int index) async {
    if (index >= state.entries.length) return;

    final entry = state.entries[index];
    final cacheKey = '${entry.timestamp.millisecondsSinceEpoch}_${entry.text}';

    if (state.insightsCache.containsKey(cacheKey)) {
      final cachedInsight = state.insightsCache[cacheKey];
      if (cachedInsight is ComprehensiveInsight) {
        emit(state.copyWith(currentInsight: cachedInsight));
        return;
      }
    }

    emit(state.copyWith(isGeneratingInsight: true));

    try {
      final entryId = entry.timestamp.millisecondsSinceEpoch.toString();
      final comprehensiveInsight = await _aiService.generateEntryInsights(
        entry.text, 
        entryId,
        currentDate: DateTime.now(), // CC: Pass current date for temporal context
      );

      final updatedCache = Map<String, ComprehensiveInsight>.from(state.insightsCache);
      updatedCache[cacheKey] = comprehensiveInsight;

      emit(
        state.copyWith(
          currentInsight: comprehensiveInsight,
          insightsCache: updatedCache,
          isGeneratingInsight: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isGeneratingInsight: false,
        ),
      );
    }
  }
}
