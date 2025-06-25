import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';
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
    
    // CP: Haptic feedback when streaming starts
    HapticFeedback.lightImpact();

    // CP: Variables for typewriter effect - declared outside try block
    final StringBuffer receivedText = StringBuffer(); // CP: Buffer for received text
    final StringBuffer displayedText = StringBuffer(); // CP: Buffer for displayed text
    Timer? typewriterTimer;
    int currentIndex = 0;
    
    try {
      
      // CP: Start typewriter effect with variable speed
      void startTypewriter() {
        typewriterTimer?.cancel();
        
        void typeNextCharacter() {
          if (currentIndex >= receivedText.length) {
            // CP: No more characters to display yet
            return;
          }
          
          final fullText = receivedText.toString();
          final char = fullText[currentIndex];
          displayedText.write(char);
          currentIndex++;
          
          // CP: Update UI with smooth character reveal
          final updatedMessages = List<ChatMessage>.from(state.messages);
          final aiMessageIndex = updatedMessages.indexWhere((msg) => msg.id == aiMessageId);
          if (aiMessageIndex != -1) {
            updatedMessages[aiMessageIndex] = ChatMessage(
              id: aiMessageId,
              text: displayedText.toString(),
              sender: ChatSender.ai,
              timestamp: DateTime.now(),
            );
            emit(state.copyWith(messages: updatedMessages, streamingMessageId: aiMessageId));
          }
          
          // CP: Variable delay based on character type
          Duration nextDelay;
          if (char == '.' || char == '!' || char == '?') {
            nextDelay = const Duration(milliseconds: 200); // CP: Pause after sentence
          } else if (char == ',' || char == ';' || char == ':') {
            nextDelay = const Duration(milliseconds: 100); // CP: Short pause after clause
          } else if (char == '\n') {
            nextDelay = const Duration(milliseconds: 150); // CP: Pause for new paragraph
          } else if (char == ' ') {
            nextDelay = const Duration(milliseconds: 30); // CP: Quick space
          } else {
            nextDelay = const Duration(milliseconds: 25); // CP: Normal character speed
          }
          
          // CP: Schedule next character
          if (currentIndex < receivedText.length) {
            typewriterTimer = Timer(nextDelay, typeNextCharacter);
          }
        }
        
        // CP: Start typing
        typeNextCharacter();
      }
      
      await for (final event in _aiService.streamChatResponse(
        messages: state.messages.sublist(0, state.messages.length - 1), // CP: Exclude the empty AI message
        currentDate: DateTime.now(),
        store: true,
        previousResponseId: state.lastResponseId,
      )) {
        switch (event) {
          case ChatStreamDelta(:final text):
            receivedText.write(text);
            // CP: Start typewriter if not already running
            if (typewriterTimer == null || !typewriterTimer!.isActive) {
              startTypewriter();
            }
            break;
            
          case ChatStreamCompleted(:final fullText, :final responseId):
            // CP: Wait for typewriter to catch up, then show final text
            typewriterTimer?.cancel();
            
            // CP: Calculate remaining time to display all text
            final remainingChars = receivedText.length - currentIndex;
            if (remainingChars > 0) {
              // CP: Speed up to finish in reasonable time
              const catchUpSpeed = Duration(milliseconds: 5);
              
              // CP: Fast-forward remaining text
              Timer.periodic(catchUpSpeed, (timer) {
                if (currentIndex >= receivedText.length) {
                  timer.cancel();
                  // CP: Show final complete text
                  _finishStreaming(aiMessageId, fullText, responseId);
                  return;
                }
                
                displayedText.write(receivedText.toString()[currentIndex]);
                currentIndex++;
                
                final updatedMessages = List<ChatMessage>.from(state.messages);
                final aiMessageIndex = updatedMessages.indexWhere((msg) => msg.id == aiMessageId);
                if (aiMessageIndex != -1) {
                  updatedMessages[aiMessageIndex] = ChatMessage(
                    id: aiMessageId,
                    text: displayedText.toString(),
                    sender: ChatSender.ai,
                    timestamp: DateTime.now(),
                  );
                  emit(state.copyWith(messages: updatedMessages, streamingMessageId: aiMessageId));
                }
              });
            } else {
              // CP: All text already displayed
              _finishStreaming(aiMessageId, fullText, responseId);
            }
            break;
            
          case ChatStreamError(:final message):
            AppLogger.error('Stream error in ChatCubit: $message');
            typewriterTimer?.cancel();
            
            final updatedMessages = List<ChatMessage>.from(state.messages);
            final aiMessageIndex = updatedMessages.indexWhere((msg) => msg.id == aiMessageId);
            if (aiMessageIndex != -1) {
              final errorText = displayedText.isEmpty 
                ? "Sorry, I couldn't get a response. Error: $message"
                : "${displayedText.toString()}\n\n[Error: $message]";
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
      typewriterTimer?.cancel();
      
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

  void _finishStreaming(String aiMessageId, String fullText, String? responseId) {
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
      
      // CP: Haptic feedback when streaming completes
      HapticFeedback.selectionClick();
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
