import 'package:equatable/equatable.dart'; // CP: Added import for Equatable
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:uuid/uuid.dart';

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  ChatCubit() : super(const ChatState());

  final Uuid _uuid = const Uuid();

  void addUserMessage(String text) {
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: text,
      sender: ChatSender.user,
      timestamp: DateTime.now(),
    );
    final newMessages = List<ChatMessage>.from(state.messages)
      ..add(userMessage);
    emit(state.copyWith(messages: newMessages));

    // CP: Simulate AI response for now
    _addAIMessage("Thinking...");
    Future.delayed(const Duration(seconds: 1), () {
      final aiResponse = ChatMessage(
        id: _uuid.v4(),
        text: "I am a friendly AI. You said: '$text'",
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
      );
      // CP: Replace the "Thinking..." message
      final updatedMessages = List<ChatMessage>.from(state.messages);
      updatedMessages.removeLast(); // CP: Remove "Thinking..."
      updatedMessages.add(aiResponse); // CP: Add actual AI response
      emit(state.copyWith(messages: updatedMessages));
    });
  }

  void _addAIMessage(String text) {
    final aiMessage = ChatMessage(
      id: _uuid.v4(),
      text: text,
      sender: ChatSender.ai,
      timestamp: DateTime.now(),
    );
    final newMessages = List<ChatMessage>.from(state.messages)..add(aiMessage);
    emit(state.copyWith(messages: newMessages));
  }

  // CP: Dummy messages for initial UI
  void loadDummyMessages() {
    final dummyMessages = [
      ChatMessage(
        id: _uuid.v4(),
        text: "Hello! How can I help you today?",
        sender: ChatSender.ai,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        text: "Hi there! I'm looking for some information.",
        sender: ChatSender.user,
        timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      ChatMessage(
        id: _uuid.v4(),
        text: "Sure, what can I help you with?",
        sender: ChatSender.ai,
        timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
      ),
    ];
    emit(state.copyWith(messages: dummyMessages));
  }
}
