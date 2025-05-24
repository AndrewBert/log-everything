part of 'bot_chat_cubit.dart';

class BotChatState extends Equatable {
  final List<BotMessage> messages;
  final bool isActive; // CP: Whether bot chat is actively generating messages
  final Set<BotPersonality>
  activePersonalities; // CP: Which bots are currently enabled
  final BotPersonality? currentlyTyping; // CP: Which bot is currently typing

  const BotChatState({
    this.messages = const [],
    this.isActive = false,
    this.activePersonalities = const {
      BotPersonality.statsBot,
      BotPersonality.concernBot,
      BotPersonality.chaosBot,
      BotPersonality.coachBot,
      BotPersonality.memoryBot,
    },
    this.currentlyTyping,
  });

  BotChatState copyWith({
    List<BotMessage>? messages,
    bool? isActive,
    Set<BotPersonality>? activePersonalities,
    BotPersonality? currentlyTyping,
    bool clearCurrentlyTyping = false,
  }) {
    return BotChatState(
      messages: messages ?? this.messages,
      isActive: isActive ?? this.isActive,
      activePersonalities: activePersonalities ?? this.activePersonalities,
      currentlyTyping:
          clearCurrentlyTyping
              ? null
              : (currentlyTyping ?? this.currentlyTyping),
    );
  }

  @override
  List<Object?> get props => [
    messages,
    isActive,
    activePersonalities,
    currentlyTyping,
  ];
}
