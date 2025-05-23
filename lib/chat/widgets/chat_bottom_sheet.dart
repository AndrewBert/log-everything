import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/chat/model/chat_message.dart';
import 'package:myapp/pages/cubit/home_page_cubit.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Import flutter_markdown

class ChatBottomSheet extends StatelessWidget {
  const ChatBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final chatCubit = context.watch<ChatCubit>();
    final messages = chatCubit.state.messages;
    final isLoading = chatCubit.state.isLoading;
    // CP: Changed from 24-hour to 12-hour format
    final DateFormat timeFormatter = DateFormat('h:mm a');

    // CP: Dismiss keyboard when tapping outside input in chat view
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20.0),
            topRight: Radius.circular(20.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              spreadRadius: 0,
              blurRadius: 8,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              tooltip: 'Collapse Chat',
              onPressed: () {
                context.read<HomePageCubit>().toggleChatOpen();
              },
            ),
            Expanded(
              child:
                  messages.isEmpty && !isLoading
                      ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 16.0,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Unlock insights from your logs!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Ask me to:",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "• Summarize recent entries\n• Find logs about a specific topic\n• Analyze patterns in your data",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "What would you like to explore?",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : ListView.builder(
                        controller: ScrollController(),
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          final isUserMessage =
                              message.sender == ChatSender.user;
                          return _buildMessageBubble(
                            context,
                            message,
                            isUserMessage,
                            timeFormatter,
                          );
                        },
                      ),
            ),
            if (isLoading) _buildThinkingIndicator(context),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingIndicator(BuildContext context) {
    final Color textColor = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            "Thinking...",
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage message,
    bool isUserMessage,
    DateFormat timeFormatter,
  ) {
    final CrossAxisAlignment bubbleAlignment =
        isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    if (isUserMessage) {
      final Color bubbleColor = Theme.of(context).colorScheme.primaryContainer;
      final Color textColor = Theme.of(context).colorScheme.onPrimaryContainer;

      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        child: Column(
          crossAxisAlignment: bubbleAlignment,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
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
                    style: TextStyle(
                      color: textColor.withAlpha(179),
                      fontSize: 10,
                    ),
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
              ).copyWith(
                p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  timeFormatter.format(message.timestamp),
                  style: TextStyle(
                    color: textColor.withAlpha(179),
                    fontSize: 10,
                  ),
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
        ),
      );
    }
  }
}
