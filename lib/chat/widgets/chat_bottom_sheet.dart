import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:myapp/utils/widget_keys.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Import flutter_markdown
import 'package:myapp/snackbar/widgets/contextual_snackbar_overlay.dart';
import 'package:myapp/snackbar/models/snackbar_message.dart';
import 'thinking_indicator.dart';

class ChatBottomSheet extends StatefulWidget {
  const ChatBottomSheet({super.key});

  @override
  State<ChatBottomSheet> createState() => _ChatBottomSheetState();
}

class _ChatBottomSheetState extends State<ChatBottomSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool isStreaming = false}) {
    if (_scrollController.hasClients) {
      // CP: Scroll to bottom with enhanced animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final targetPosition = _scrollController.position.maxScrollExtent;
          final currentPosition = _scrollController.position.pixels;
          final distance = (targetPosition - currentPosition).abs();

          // CP: Adjust animation based on distance and streaming state
          final duration = isStreaming
              ? Duration(milliseconds: (150 + distance * 0.5).round().clamp(150, 400))
              : const Duration(milliseconds: 300);

          final curve = isStreaming
              ? Curves
                    .linearToEaseOut // CP: Smoother for streaming
              : Curves.easeOutCubic; // CP: Bouncier for new messages

          _scrollController.animateTo(
            targetPosition,
            duration: duration,
            curve: curve,
          );
        }
      });
    }
  }

  bool _shouldShowThinkingIndicator(ChatCubit chatCubit) {
    // CP: Only show thinking indicator if we're loading and haven't started streaming
    if (!chatCubit.state.isLoading) return false;
    if (chatCubit.state.streamingMessageId == null) return true;

    // CP: Check if the streaming message has any text yet
    final streamingMessage = chatCubit.state.messages.firstWhere(
      (msg) => msg.id == chatCubit.state.streamingMessageId,
      orElse: () => ChatMessage(id: '', text: '', sender: ChatSender.ai, timestamp: DateTime.now()),
    );

    return streamingMessage.text.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final chatCubit = context.watch<ChatCubit>();
    final messages = chatCubit.state.messages;
    final isLoading = chatCubit.state.isLoading;
    // CP: Changed from 24-hour to 12-hour format
    final DateFormat timeFormatter = DateFormat('h:mm a');

    // CP: Scroll to bottom when new messages are added or streaming updates
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (previous, current) =>
          previous.messages.length < current.messages.length ||
          (current.streamingMessageId != null && previous.messages != current.messages),
      listener: (context, state) {
        final isStreaming = state.streamingMessageId != null;
        _scrollToBottom(isStreaming: isStreaming);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // CP: Full-screen chat header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withAlpha(50),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        IconButton(
                          key: chatCloseButton,
                          icon: const Icon(Icons.close),
                          tooltip: 'Close Chat',
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        Expanded(
                          child: Text(
                            'Chat with AI',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // CP: Spacer to center the title
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: messages.isEmpty && !isLoading
                      ? SingleChildScrollView(
                          child: Padding(
                            key: chatWelcomeMessage,
                            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.psychology_outlined,
                                  size: 48,
                                  color: Theme.of(context).colorScheme.primary.withAlpha(128),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "Unlock insights from your logs!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Ask me to:",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSuggestionItem(context, "📊", "Summarize recent entries"),
                                      const SizedBox(height: 12),
                                      _buildSuggestionItem(context, "🔍", "Find logs about a specific topic"),
                                      const SizedBox(height: 12),
                                      _buildSuggestionItem(context, "📈", "Analyze patterns in your data"),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  "What would you like to explore?",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: chatMessagesList,
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          itemCount: messages.length + (isLoading && _shouldShowThinkingIndicator(chatCubit) ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show thinking indicator as the last item
                            if (index == messages.length && isLoading && _shouldShowThinkingIndicator(chatCubit)) {
                              return _buildThinkingIndicator(context);
                            }
                            final message = messages[index];
                            final isUserMessage = message.sender == ChatSender.user;
                            return _buildMessageBubble(context, message, isUserMessage, timeFormatter);
                          },
                        ),
                ),
              ],
            ),
            // CP: Snackbar overlay at top of chat
            const ContextualSnackbarOverlay(contextFilter: SnackbarContext.chat),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator(BuildContext context) {
    return Padding(
      key: chatThinkingIndicator,
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ThinkingIndicator(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ChatMessage message, bool isUserMessage, DateFormat timeFormatter) {
    final CrossAxisAlignment bubbleAlignment = isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final chatCubit = context.watch<ChatCubit>();
    final isStreaming = message.id == chatCubit.state.streamingMessageId;

    if (isUserMessage) {
      final Color bubbleColor = Theme.of(context).colorScheme.primaryContainer;
      final Color textColor = Theme.of(context).colorScheme.onPrimaryContainer;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: bubbleAlignment,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(16.0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message.text, style: TextStyle(color: textColor, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    timeFormatter.format(message.timestamp),
                    style: TextStyle(color: textColor.withAlpha(179), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      final Color textColor = Theme.of(context).colorScheme.onSurfaceVariant;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Column(
          crossAxisAlignment: bubbleAlignment,
          children: [
            MarkdownBody(
              data: message.text,
              styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context),
              ).copyWith(p: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, fontSize: 16)),
            ),
            // Only show timestamp and assistant label after streaming is complete
            if (!isStreaming) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    timeFormatter.format(message.timestamp),
                    style: TextStyle(color: textColor.withAlpha(179), fontSize: 10),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      'Assistant',
                      style: TextStyle(color: textColor.withAlpha(150), fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildSuggestionItem(BuildContext context, String emoji, String text) {
    return Row(
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 15,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
