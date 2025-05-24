import 'dart:async';
import 'dart:math';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/experimental/bot_chat/model/bot_message.dart';
import 'package:myapp/experimental/bot_chat/model/bot_personality.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/utils/logger.dart';
import 'package:uuid/uuid.dart';

part 'bot_chat_state.dart';

class BotChatCubit extends Cubit<BotChatState> {
  final AiService _aiService;
  final Uuid _uuid = const Uuid();
  final Random _random = Random();
  Timer? _messageTimer;
  Timer? _typingTimer;

  BotChatCubit({required AiService aiService})
    : _aiService = aiService,
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
  void _scheduleNextMessage() {
    if (!state.isActive) return;

    // CP: Random delay between 3-8 seconds for active chat feel
    final delay = Duration(seconds: 3 + _random.nextInt(6));

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

        // CP: Generate message using AI service
        final message = await _generateBotMessage(chosenBot);
        _addBotMessage(message, chosenBot);

        // CP: Schedule next message
        _scheduleNextMessage();
      });
    } catch (e) {
      AppLogger.error('CP: Error generating bot message: $e');
      emit(state.copyWith(clearCurrentlyTyping: true));
      _scheduleNextMessage();
    }
  }

  // CP: Generate bot message using AI service with personality-specific prompts
  Future<String> _generateBotMessage(BotPersonality personality) async {
    try {
      final systemPrompt = _buildPersonalityPrompt(personality);
      final userPrompt = _buildContextPrompt();

      // CP: Create a simple message list for the AI service
      final messages = [
        // CP: We'll use the existing ChatMessage format but adapt it
        // CP: For now, use a simple prompt structure
      ];

      // CP: For Phase 1, use fallback messages while we set up AI integration
      return _getFallbackMessage(personality);
    } catch (e) {
      AppLogger.error('CP: Error calling AI service for bot message: $e');
      return _getFallbackMessage(personality);
    }
  }

  // CP: Build personality-specific system prompt
  String _buildPersonalityPrompt(BotPersonality personality) {
    final description = BotPersonalityTraits.descriptions[personality] ?? '';

    switch (personality) {
      case BotPersonality.statsBot:
        return "You are StatsBot 📊. You're obsessed with data and patterns. Keep responses short and focused on numbers, trends, and statistics. Be analytical but enthusiastic about data insights.";
      case BotPersonality.concernBot:
        return "You are ConcernBot 💙. You care deeply about wellbeing and health. Keep responses short, supportive, and focused on checking in on emotional/physical wellness.";
      case BotPersonality.chaosBot:
        return "You are ChaosBot 🔥. You're snarky and point out contradictions or unusual patterns. Keep responses short, witty, but not mean-spirited.";
      case BotPersonality.coachBot:
        return "You are CoachBot 💪. You're motivational with a tough-love approach. Keep responses short, direct, and focused on goals and improvement.";
      case BotPersonality.memoryBot:
        return "You are MemoryBot 🧠. You're nostalgic and remember past patterns. Keep responses short and focused on historical comparisons and memories.";
    }
  }

  // CP: Build context prompt based on recent activity (placeholder for Phase 1)
  String _buildContextPrompt() {
    return "Generate a short, conversational message about recent user activity patterns. Keep it under 50 words and stay in character.";
  }

  // CP: Fallback messages for each personality (Phase 1 implementation)
  String _getFallbackMessage(BotPersonality personality) {
    final fallbackMessages = {
      BotPersonality.statsBot: [
        "I'm seeing some interesting patterns in the data today! 📈",
        "Your entry frequency is up 23% this week!",
        "Data point: You've logged 5 different categories today.",
        "Trend alert: Your logging consistency is improving! 📊",
        "Stats check: Most active logging time is 3:30 PM.",
      ],
      BotPersonality.concernBot: [
        "Hope you're taking care of yourself today 💙",
        "Remember to check in with how you're feeling.",
        "I noticed you haven't logged any wellness entries lately.",
        "Your wellbeing matters - don't forget self-care! 🤗",
        "How are your energy levels today?",
      ],
      BotPersonality.chaosBot: [
        "Logged 'productive day' and then 'Netflix binge'? Classic! 🔥",
        "Your productivity and procrastination entries are perfectly balanced... as all things should be.",
        "Interesting contradiction: 'healthy eating' followed by 'pizza night' 😏",
        "I see chaos in your data and I'm here for it!",
        "Your log entries tell quite the story... a chaotic one! 🎭",
      ],
      BotPersonality.coachBot: [
        "Time to step up your logging game! 💪",
        "I see potential for improvement in your consistency.",
        "No excuses - let's hit those daily logging goals!",
        "Your future self will thank you for these entries.",
        "Push harder! Your goals won't achieve themselves! 🏆",
      ],
      BotPersonality.memoryBot: [
        "Remember when you started logging 3 weeks ago? Look how far you've come! 🧠",
        "This reminds me of that pattern you had last month...",
        "Nostalgic moment: Your first entry was so different from now.",
        "I remember when you used to log differently... interesting evolution!",
        "Past you would be proud of current you's logging habits! 📖",
      ],
    };

    final messages =
        fallbackMessages[personality] ??
        ['Hello from ${personality.displayName}!'];
    return messages[_random.nextInt(messages.length)];
  }

  @override
  Future<void> close() {
    _messageTimer?.cancel();
    _typingTimer?.cancel();
    return super.close();
  }
}
