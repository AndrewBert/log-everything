import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/utils/logger.dart'; // CP: Import AppLogger
import 'package:uuid/uuid.dart';
// CP: Import EntryRepository - REMOVED as it's unused

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  // CP: Add AiService dependency
  final AiService _aiService;
  final Uuid _uuid = const Uuid();

  // CP: Update constructor to accept AiService
  ChatCubit({required AiService aiService}) : _aiService = aiService, super(const ChatState());

  Future<void> addUserMessage(String text) async {
    // CP: Make method async
    final userMessage = ChatMessage(id: _uuid.v4(), text: text, sender: ChatSender.user, timestamp: DateTime.now());

    // CP: Add user message and set loading state
    final messagesWithUser = List<ChatMessage>.from(state.messages)..add(userMessage);
    emit(state.copyWith(messages: messagesWithUser, isLoading: true));

    try {
      // CP: Get the full conversation history to send to the API
      // CP: This includes the new user message we just added to the state for context.
      final response = await _aiService.getChatResponse(
        messages: state.messages,
        currentDate: DateTime.now(),
        store: true, // CP: Store conversations on OpenAI servers
        previousResponseId: state.lastResponseId, // CP: Chain to previous response
      );
      final String aiResponseText = response.$1;
      final String? newResponseId = response.$2;

      final aiMessage = ChatMessage(
        id: _uuid.v4(),
        text: aiResponseText,
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
      );
      final messagesWithAi = List<ChatMessage>.from(state.messages)..add(aiMessage);
      emit(state.copyWith(messages: messagesWithAi, isLoading: false, lastResponseId: newResponseId));
    } on AiServiceException catch (e) {
      AppLogger.error('AiServiceException in ChatCubit: ${e.message}', error: e.underlyingError);
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        text: "Sorry, I couldn't get a response. Error: ${e.message}",
        sender: ChatSender.ai, // CP: Error shown as an AI message
        timestamp: DateTime.now(),
      );
      final messagesWithError = List<ChatMessage>.from(state.messages)..add(errorMessage);
      emit(state.copyWith(messages: messagesWithError, isLoading: false));
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error in ChatCubit: $e', stackTrace: stackTrace);
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        text: "Sorry, an unexpected error occurred while fetching the chat response.",
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
      );
      final messagesWithError = List<ChatMessage>.from(state.messages)..add(errorMessage);
      emit(state.copyWith(messages: messagesWithError, isLoading: false));
    }
  }

  Future<void> addUserMessageStreaming(String text) async {
    // CP: New method for streaming responses
    final userMessage = ChatMessage(id: _uuid.v4(), text: text, sender: ChatSender.user, timestamp: DateTime.now());

    // CP: Add user message and set loading state
    final messagesWithUser = List<ChatMessage>.from(state.messages)..add(userMessage);
    emit(state.copyWith(messages: messagesWithUser, isLoading: true));

    // CP: Create AI message placeholder
    final aiMessageId = _uuid.v4();
    final aiMessage = ChatMessage(
      id: aiMessageId,
      text: '',
      sender: ChatSender.ai,
      timestamp: DateTime.now(),
    );
    final messagesWithAi = List<ChatMessage>.from(state.messages)..add(aiMessage);
    emit(state.copyWith(messages: messagesWithAi, isLoading: true, streamingMessageId: aiMessageId));

    try {
      final StringBuffer accumulatedText = StringBuffer();
      
      await for (final event in _aiService.streamChatResponse(
        messages: state.messages.sublist(0, state.messages.length - 1), // CP: Exclude the empty AI message
        currentDate: DateTime.now(),
        store: true,
        previousResponseId: state.lastResponseId,
      )) {
        switch (event) {
          case ChatStreamDelta(:final text):
            accumulatedText.write(text);
            
            // CP: Update the AI message with accumulated text
            final updatedMessages = List<ChatMessage>.from(state.messages);
            final aiMessageIndex = updatedMessages.indexWhere((msg) => msg.id == aiMessageId);
            if (aiMessageIndex != -1) {
              updatedMessages[aiMessageIndex] = ChatMessage(
                id: aiMessageId,
                text: accumulatedText.toString(),
                sender: ChatSender.ai,
                timestamp: DateTime.now(),
              );
              emit(state.copyWith(messages: updatedMessages, streamingMessageId: aiMessageId));
            }
            break;
            
          case ChatStreamCompleted(:final fullText, :final responseId):
            // CP: Final update with complete text
            final updatedMessages = List<ChatMessage>.from(state.messages);
            final aiMessageIndex = updatedMessages.indexWhere((msg) => msg.id == aiMessageId);
            if (aiMessageIndex != -1) {
              updatedMessages[aiMessageIndex] = ChatMessage(
                id: aiMessageId,
                text: fullText,
                sender: ChatSender.ai,
                timestamp: DateTime.now(),
              );
              emit(state.copyWith(
                messages: updatedMessages,
                isLoading: false,
                lastResponseId: responseId,
                clearStreamingMessageId: true,
              ));
            }
            break;
            
          case ChatStreamError(:final message):
            AppLogger.error('Stream error in ChatCubit: $message');
            final updatedMessages = List<ChatMessage>.from(state.messages);
            final aiMessageIndex = updatedMessages.indexWhere((msg) => msg.id == aiMessageId);
            if (aiMessageIndex != -1) {
              final errorText = accumulatedText.isEmpty 
                ? "Sorry, I couldn't get a response. Error: $message"
                : "${accumulatedText.toString()}\n\n[Error: $message]";
              updatedMessages[aiMessageIndex] = ChatMessage(
                id: aiMessageId,
                text: errorText,
                sender: ChatSender.ai,
                timestamp: DateTime.now(),
              );
              emit(state.copyWith(
                messages: updatedMessages,
                isLoading: false,
                clearStreamingMessageId: true,
              ));
            }
            break;
        }
      }
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error in streaming chat: $e', stackTrace: stackTrace);
      final updatedMessages = List<ChatMessage>.from(state.messages);
      final aiMessageIndex = updatedMessages.indexWhere((msg) => msg.id == aiMessageId);
      if (aiMessageIndex != -1) {
        updatedMessages[aiMessageIndex] = ChatMessage(
          id: aiMessageId,
          text: "Sorry, an unexpected error occurred while streaming the response.",
          sender: ChatSender.ai,
          timestamp: DateTime.now(),
        );
        emit(state.copyWith(
          messages: updatedMessages,
          isLoading: false,
          clearStreamingMessageId: true,
        ));
      }
    }
  }

  // CP: _addAIMessage is no longer needed as AI responses are handled by addUserMessage
  // void _addAIMessage(String text) { ... }

  // CP: Dummy messages for initial UI (commented out as per previous request)
  void loadDummyMessages() {
    // ... (dummy messages code commented out)
    emit(state.copyWith(messages: []));
  }
}
