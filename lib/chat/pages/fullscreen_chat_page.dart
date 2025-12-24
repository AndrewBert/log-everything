import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:myapp/chat/widgets/thinking_indicator.dart';
import 'package:myapp/utils/chat_keys.dart';

class FullscreenChatPage extends StatelessWidget {
  const FullscreenChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: ChatKeys.fullscreenChatPage,
      appBar: AppBar(
        title: const Text('Chat with AI'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _ChatMessagesList(),
          ),
          _ChatInputField(),
        ],
      ),
    );
  }
}

class _ChatMessagesList extends StatefulWidget {
  @override
  State<_ChatMessagesList> createState() => _ChatMessagesListState();
}

class _ChatMessagesListState extends State<_ChatMessagesList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  bool _shouldShowThinkingIndicator(ChatState state) {
    if (!state.isLoading) return false;
    if (state.streamingMessageId == null) return true;

    final streamingMessage = state.messages.firstWhere(
      (msg) => msg.id == state.streamingMessageId,
      orElse: () => ChatMessage(id: '', text: '', sender: ChatSender.ai, timestamp: DateTime.now()),
    );

    return streamingMessage.text.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatCubit, ChatState>(
      listenWhen: (previous, current) => previous.messages.length < current.messages.length,
      listener: (context, state) {
        _scrollToBottom();
      },
      child: BlocBuilder<ChatCubit, ChatState>(
        builder: (context, state) {
          final messages = state.messages;
          final isLoading = state.isLoading;
          final DateFormat timeFormatter = DateFormat('h:mm a');

          return ListView.builder(
            key: ChatKeys.fullscreenChatMessagesList,
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: messages.length + (isLoading && _shouldShowThinkingIndicator(state) ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length && isLoading && _shouldShowThinkingIndicator(state)) {
                return _buildThinkingIndicator();
              }
              final message = messages[index];
              final isUserMessage = message.sender == ChatSender.user;
              final isStreaming = message.id == state.streamingMessageId;
              return _buildMessageBubble(context, message, isUserMessage, isStreaming, timeFormatter);
            },
          );
        },
      ),
    );
  }

  Widget _buildThinkingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          ThinkingIndicator(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage message,
    bool isUserMessage,
    bool isStreaming,
    DateFormat timeFormatter,
  ) {
    final CrossAxisAlignment bubbleAlignment = isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;

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
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
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
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ),
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
                      style: TextStyle(
                        color: textColor.withAlpha(150),
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
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
}

class _ChatInputField extends StatefulWidget {
  @override
  State<_ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<_ChatInputField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    context.read<ChatCubit>().addUserMessageStreaming(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withAlpha(50),
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: ChatKeys.fullscreenChatTextField,
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 10.0,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSubmit(),
              ),
            ),
            const SizedBox(width: 8.0),
            IconButton(
              key: ChatKeys.fullscreenChatSendButton,
              icon: const Icon(Icons.send),
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
