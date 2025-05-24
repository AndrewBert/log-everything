import 'dart:async';
import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/experimental/bot_chat/model/bot_message.dart';
import 'package:myapp/experimental/bot_chat/model/bot_personality.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/entry/repository/entry_repository.dart'; // CP: Add entry repository
import 'package:myapp/utils/logger.dart';
import 'package:uuid/uuid.dart';

part 'bot_chat_state.dart';

class BotChatCubit extends Cubit<BotChatState> {
  final AiService _aiService;
  final EntryRepository
  _entryRepository; // CP: Add entry repository for context
  final Uuid _uuid = const Uuid();
  final Random _random = Random();
  Timer? _messageTimer;
  Timer? _typingTimer;

  BotChatCubit({
    required AiService aiService,
    required EntryRepository
    entryRepository, // CP: Add entry repository dependency
  }) : _aiService = aiService,
       _entryRepository = entryRepository,
       super(const BotChatState());

  // CP: Start the bot chat simulation
  void startBotChat() {
    if (state.isActive) return;

    AppLogger.info('CP: Starting bot chat simulation');
    emit(state.copyWith(isActive: true));

    // CP: Schedule first message after a short delay
    _scheduleNextMessage();
  }

  // CP: Stop the bot chat simulation
  void stopBotChat() {
    AppLogger.info('CP: Stopping bot chat simulation');
    _messageTimer?.cancel();
    _typingTimer?.cancel();
    emit(state.copyWith(isActive: false, clearCurrentlyTyping: true));
  }

  // CP: Trigger bot analysis when new entry is added
  void onEntryAdded() {
    if (!state.isActive) return;

    AppLogger.info('CP: New entry detected, triggering bot analysis');

    // CP: Cancel current timer and schedule immediate response
    _messageTimer?.cancel();
    _scheduleNextMessage(immediateResponse: true);
  }

  // CP: Add a new bot message
  void _addBotMessage(String text, BotPersonality personality) {
    final message = BotMessage(
      id: _uuid.v4(),
      text: text,
      botPersonality: personality,
      timestamp: DateTime.now(),
    );

    final updatedMessages = List<BotMessage>.from(state.messages)..add(message);
    emit(state.copyWith(messages: updatedMessages, clearCurrentlyTyping: true));

    AppLogger.info(
      'CP: Added bot message from ${personality.displayName}: ${text.length > 50 ? '${text.substring(0, 50)}...' : text}',
    );
  }

  // CP: Schedule the next message with realistic timing
  void _scheduleNextMessage({bool immediateResponse = false}) {
    if (!state.isActive) return;

    // CP: Immediate response for new entries, otherwise random delay
    final delay =
        immediateResponse
            ? Duration(
              milliseconds: 500 + _random.nextInt(1500),
            ) // 0.5-2 seconds for immediate
            : Duration(
              seconds: 3 + _random.nextInt(6),
            ); // 3-8 seconds for normal chat

    _messageTimer = Timer(delay, () {
      if (!state.isActive) return;
      _generateNextMessage();
    });
  }

  // CP: Generate and send the next bot message
  void _generateNextMessage() async {
    if (!state.isActive) return;

    try {
      // CP: Choose a random active bot personality
      final activePersonalities = state.activePersonalities.toList();
      if (activePersonalities.isEmpty) {
        _scheduleNextMessage();
        return;
      }

      final chosenBot =
          activePersonalities[_random.nextInt(activePersonalities.length)];

      // CP: Show typing indicator
      emit(state.copyWith(currentlyTyping: chosenBot));

      // CP: Simulate typing delay (1-3 seconds)
      final typingDelay = Duration(seconds: 1 + _random.nextInt(3));

      _typingTimer = Timer(typingDelay, () async {
        if (!state.isActive) return;

        try {
          // CP: Generate message using AI service
          final message = await _generateBotMessage(chosenBot);
          _addBotMessage(message, chosenBot);
        } catch (e) {
          AppLogger.error(
            'CP: Failed to generate AI message, using fallback: $e',
          );
          // CP: Use fallback if AI generation fails
          final fallbackMessage = _getFallbackMessage(
            chosenBot,
            state.messages.take(5).toList(),
          );
          _addBotMessage(fallbackMessage, chosenBot);
        }

        // CP: Schedule next message
        _scheduleNextMessage();
      });
    } catch (e) {
      AppLogger.error('CP: Error in message generation flow: $e');
      emit(state.copyWith(clearCurrentlyTyping: true));
      _scheduleNextMessage();
    }
  }

  // CP: Generate bot message using AI service with personality-specific prompts
  Future<String> _generateBotMessage(BotPersonality personality) async {
    try {
      // CP: Get recent entries for context
      final recentEntries = await _entryRepository.getRecentEntries(limit: 10);

      // CP: Get recent bot messages for conversation context
      final recentBotMessages = state.messages.take(5).toList();

      // CP: Generate context-aware message
      final message = await _aiService.generateBotMessage(
        personality: personality,
        recentEntries: recentEntries,
        recentBotMessages: recentBotMessages,
      );

      return message;
    } catch (e) {
      AppLogger.error('CP: Error calling AI service for bot message: $e');
      rethrow;
    }
  }

  // CP: Get fallback message based on personality and recent conversation
  String _getFallbackMessage(
    BotPersonality personality,
    List<BotMessage> recentMessages,
  ) {
    final lastBot =
        recentMessages.isNotEmpty ? recentMessages.first.botPersonality : null;

    switch (personality) {
      case BotPersonality.statsBot:
        if (lastBot == BotPersonality.chaosBot) {
          return "Chaos? I see PATTERNS! 📊";
        } else if (lastBot == BotPersonality.concernBot) {
          return "Numbers don't lie about your health trends 📈";
        }
        return "Let me crunch these numbers... 🤓";

      case BotPersonality.concernBot:
        if (lastBot == BotPersonality.coachBot) {
          return "Maybe be less harsh? Just saying... 😬";
        } else if (lastBot == BotPersonality.chaosBot) {
          return "That's... actually concerning 😟";
        }
        return "Are you taking care of yourself? 🥺";

      case BotPersonality.chaosBot:
        if (lastBot == BotPersonality.statsBot) {
          return "Stats are boring! Where's the CHAOS? 🔥";
        } else if (lastBot == BotPersonality.memoryBot) {
          return "Stop living in the past! Embrace the chaos! 😈";
        }
        return "This is delightfully unhinged 🤪";

      case BotPersonality.coachBot:
        if (lastBot == BotPersonality.concernBot) {
          return "Stop coddling them! Results matter! 💪";
        } else if (lastBot == BotPersonality.chaosBot) {
          return "Focus! Channel that chaos into productivity! 😤";
        }
        return "Time to level up! No excuses! 🔥";

      case BotPersonality.memoryBot:
        if (lastBot == BotPersonality.chaosBot) {
          return "This reminds me of last Tuesday's chaos... 🧠";
        } else if (lastBot == BotPersonality.coachBot) {
          return "Remember when you said that before? 👀";
        }
        return "I've seen this pattern before... 🔍";
    }
  }

  @override
  Future<void> close() {
    _messageTimer?.cancel();
    _typingTimer?.cancel();
    return super.close();
  }
}
