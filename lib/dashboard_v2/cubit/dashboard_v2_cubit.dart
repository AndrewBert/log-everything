import 'dart:convert';

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
      final comprehensiveInsight = await _generateComprehensiveInsight(entry);

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

  Future<ComprehensiveInsight> _generateComprehensiveInsight(Entry entry) async {
    final response = await _aiService.generateEntryInsights(entry.text);
    
    final insights = <Insight>[];
    final now = DateTime.now();
    String? priority;
    
    try {
      final json = await _parseJson(response) ?? {};
      priority = json['priority'] as String?;
      
      if (json.containsKey('summary')) {
        insights.add(Insight(
          id: '${entry.timestamp.millisecondsSinceEpoch}_summary',
          type: InsightType.summary,
          title: 'Summary',
          content: json['summary'] as String,
          generatedAt: now,
        ));
      }
      
      if (json.containsKey('emotion') && json['emotion'] is Map) {
        final emotionData = json['emotion'] as Map<String, dynamic>;
        final primary = emotionData['primary'] as String? ?? '';
        final secondary = (emotionData['secondary'] as List?)?.cast<String>() ?? [];
        final intensity = emotionData['intensity'] as String? ?? 'medium';
        
        insights.add(Insight(
          id: '${entry.timestamp.millisecondsSinceEpoch}_emotion',
          type: InsightType.emotion,
          title: 'Emotional Analysis',
          content: primary,
          generatedAt: now,
          metadata: {
            'secondary': secondary,
            'intensity': intensity,
          },
        ));
      }
      
      if (json.containsKey('pattern')) {
        insights.add(Insight(
          id: '${entry.timestamp.millisecondsSinceEpoch}_pattern',
          type: InsightType.pattern,
          title: 'Pattern Recognition',
          content: json['pattern'] as String,
          generatedAt: now,
        ));
      }
      
      if (json.containsKey('theme')) {
        insights.add(Insight(
          id: '${entry.timestamp.millisecondsSinceEpoch}_theme',
          type: InsightType.theme,
          title: 'Theme',
          content: json['theme'] as String,
          generatedAt: now,
        ));
      }
      
      if (json.containsKey('recommendation')) {
        insights.add(Insight(
          id: '${entry.timestamp.millisecondsSinceEpoch}_recommendation',
          type: InsightType.recommendation,
          title: 'Recommendation',
          content: json['recommendation'] as String,
          generatedAt: now,
        ));
      }
    } catch (e) {
      insights.add(Insight(
        id: '${entry.timestamp.millisecondsSinceEpoch}_summary',
        type: InsightType.summary,
        title: 'Summary',
        content: response,
        generatedAt: now,
      ));
    }
    
    final comprehensiveInsight = ComprehensiveInsight(
      entryId: '${entry.timestamp.millisecondsSinceEpoch}',
      entryText: entry.text,
      insights: insights,
      generatedAt: now,
      priority: priority,
    );
    
    return comprehensiveInsight;
  }

  Future<Map<String, dynamic>?> _parseJson(String text) async {
    try {
      final jsonStart = text.indexOf('{');
      final jsonEnd = text.lastIndexOf('}') + 1;
      if (jsonStart == -1 || jsonEnd == 0) return null;
      
      final jsonStr = text.substring(jsonStart, jsonEnd);
      final decoded = jsonDecode(jsonStr);
      
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
