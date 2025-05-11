import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/chat/cubit/chat_cubit.dart';
import 'package:myapp/chat/model/chat_message.dart';

class ChatBottomSheet extends StatelessWidget {
  const ChatBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final chatCubit = context.watch<ChatCubit>();
    final messages = chatCubit.state.messages;
    final DateFormat timeFormatter = DateFormat('HH:mm');

    // CP: Determine the height of the bottom sheet.
    // CP: For now, let's make it a fixed portion of the screen,
    // CP: but not exceeding a certain max height.
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomSheetHeight = (screenHeight * 0.4).clamp(200.0, 400.0);

    return Container(
      height: bottomSheetHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
        boxShadow: [
          BoxShadow(
            // CP: Changed from withOpacity to withValues to avoid precision loss
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, -4), // CP: shadow on the top
          ),
        ],
      ),
      child: Column(
        children: [
          // CP: Optional: Add a small drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          Expanded(
            child:
                messages.isEmpty
                    ? Center(
                      child: Text(
                        "No messages yet. Start a conversation!",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                    : ListView.builder(
                      reverse:
                          true, // CP: To show latest messages at the bottom
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        // CP: Display messages in reverse order for chat-like appearance
                        final message = messages[messages.length - 1 - index];
                        final isUserMessage = message.sender == ChatSender.user;
                        return _buildMessageBubble(
                          context,
                          message,
                          isUserMessage,
                          timeFormatter,
                        );
                      },
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
    final alignment =
        isUserMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color =
        isUserMessage
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.secondaryContainer;
    final textColor =
        isUserMessage
            ? Theme.of(context).colorScheme.onPrimaryContainer
            : Theme.of(context).colorScheme.onSecondaryContainer;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  timeFormatter.format(message.timestamp),
                  // CP: Changed from withOpacity to withValues to avoid precision loss
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
