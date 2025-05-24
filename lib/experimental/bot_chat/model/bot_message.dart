import 'package:equatable/equatable.dart';
import 'bot_personality.dart';

// CP: Bot message model for Discord-style chat
class BotMessage extends Equatable {
  final String id;
  final String text;
  final BotPersonality botPersonality;
  final DateTime timestamp;
  final bool isTyping; // CP: For simulating typing indicator

  const BotMessage({
    required this.id,
    required this.text,
    required this.botPersonality,
    required this.timestamp,
    this.isTyping = false,
  });

  BotMessage copyWith({
    String? id,
    String? text,
    BotPersonality? botPersonality,
    DateTime? timestamp,
    bool? isTyping,
  }) {
    return BotMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      botPersonality: botPersonality ?? this.botPersonality,
      timestamp: timestamp ?? this.timestamp,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  @override
  List<Object?> get props => [id, text, botPersonality, timestamp, isTyping];
}
