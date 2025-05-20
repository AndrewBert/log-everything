part of 'chat_cubit.dart';

class ChatState extends Equatable {
  // CP: Changed from 'with' to 'extends'
  final List<ChatMessage> messages;
  final bool
  isLoading; // CP: To show a loading indicator if needed in the future

  const ChatState({this.messages = const [], this.isLoading = false});

  ChatState copyWith({List<ChatMessage>? messages, bool? isLoading}) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [messages, isLoading];
}
