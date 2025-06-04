part of 'chat_cubit.dart';

class ChatState extends Equatable {
  // CP: Changed from 'with' to 'extends'
  final List<ChatMessage> messages;
  final bool isLoading; // CP: To show a loading indicator if needed in the future
  final String? lastResponseId; // CP: Store the last OpenAI response ID for conversation context

  const ChatState({this.messages = const [], this.isLoading = false, this.lastResponseId});
  ChatState copyWith({List<ChatMessage>? messages, bool? isLoading, String? lastResponseId}) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      lastResponseId: lastResponseId ?? this.lastResponseId,
    );
  }

  @override
  List<Object?> get props => [messages, isLoading, lastResponseId];
}
