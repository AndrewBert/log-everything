import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:myapp/entry/repository/entry_repository.dart';
import 'package:myapp/entry/entry.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/chat/model/chat_message.dart';
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
    final cacheKey = entry.text;

    // CP: Check cache first
    if (state.insightsCache.containsKey(cacheKey)) {
      emit(state.copyWith(currentInsight: state.insightsCache[cacheKey]));
      return;
    }

    emit(state.copyWith(isGeneratingInsight: true));

    try {
      // CP: For now, generate a simple summary
      final prompt =
          '''
      Provide a brief, insightful summary of this log entry in 1-2 sentences:
      "${entry.text}"
      
      Keep it concise and highlight the key point or emotion.
      ''';

      final messages = [
        ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: prompt,
          sender: ChatSender.user,
          timestamp: DateTime.now(),
        ),
      ];
      final (insight, _) = await _aiService.getChatResponse(messages: messages);

      // CP: Update cache and current insight
      final updatedCache = Map<String, String>.from(state.insightsCache);
      updatedCache[cacheKey] = insight;

      emit(
        state.copyWith(
          currentInsight: insight,
          insightsCache: updatedCache,
          isGeneratingInsight: false,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isGeneratingInsight: false,
          currentInsight: 'Unable to generate insight',
        ),
      );
    }
  }
}
