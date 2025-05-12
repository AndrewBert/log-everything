import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:myapp/services/ai_service.dart';
import 'package:myapp/utils/logger.dart'; // CP: Import AppLogger
import 'package:uuid/uuid.dart';
import '../../entry/repository/entry_repository.dart'; // CP: Import EntryRepository

part 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  // CP: Add AiService dependency
  final AiService _aiService;
  // CP: Add EntryRepository dependency
  final EntryRepository _entryRepository;
  final Uuid _uuid = const Uuid();

  // CP: Update constructor to accept AiService and EntryRepository
  ChatCubit({
    required AiService aiService,
    required EntryRepository entryRepository,
  }) : _aiService = aiService,
       _entryRepository = entryRepository, // CP: Initialize EntryRepository
       super(const ChatState());

  Future<void> addUserMessage(String text) async {
    // CP: Make method async
    final userMessage = ChatMessage(
      id: _uuid.v4(),
      text: text,
      sender: ChatSender.user,
      timestamp: DateTime.now(),
    );

    // CP: Add user message and set loading state
    final messagesWithUser = List<ChatMessage>.from(state.messages)
      ..add(userMessage);
    emit(state.copyWith(messages: messagesWithUser, isLoading: true));

    try {
      // CP: Get the full conversation history to send to the API
      // CP: This includes the new user message we just added to the state for context.
      // CP: Fetch log context from EntryRepository
      final String logContext =
          await _entryRepository.getAllEntriesAsLogContext();

      final String aiResponseText = await _aiService.getChatResponse(
        messages: state.messages,
        logContext: logContext, // CP: Pass logContext to the service
      );

      final aiMessage = ChatMessage(
        id: _uuid.v4(),
        text: aiResponseText,
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
      );
      final messagesWithAi = List<ChatMessage>.from(state.messages)
        ..add(aiMessage);
      emit(state.copyWith(messages: messagesWithAi, isLoading: false));
    } on AiServiceException catch (e) {
      AppLogger.error(
        'AiServiceException in ChatCubit: ${e.message}',
        error: e.underlyingError,
      );
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        text: "Sorry, I couldn't get a response. Error: ${e.message}",
        sender: ChatSender.ai, // CP: Error shown as an AI message
        timestamp: DateTime.now(),
      );
      final messagesWithError = List<ChatMessage>.from(state.messages)
        ..add(errorMessage);
      emit(state.copyWith(messages: messagesWithError, isLoading: false));
    } catch (e, stackTrace) {
      AppLogger.error(
        'Unexpected error in ChatCubit: $e',
        stackTrace: stackTrace,
      );
      final errorMessage = ChatMessage(
        id: _uuid.v4(),
        text:
            "Sorry, an unexpected error occurred while fetching the chat response.",
        sender: ChatSender.ai,
        timestamp: DateTime.now(),
      );
      final messagesWithError = List<ChatMessage>.from(state.messages)
        ..add(errorMessage);
      emit(state.copyWith(messages: messagesWithError, isLoading: false));
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
