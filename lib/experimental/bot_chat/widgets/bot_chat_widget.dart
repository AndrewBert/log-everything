import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:myapp/experimental/bot_chat/cubit/bot_chat_cubit.dart';
import 'package:myapp/experimental/bot_chat/model/bot_message.dart';
import 'package:myapp/experimental/bot_chat/model/bot_personality.dart';

class BotChatWidget extends StatelessWidget {
  const BotChatWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BotChatCubit, BotChatState>(
      builder: (context, state) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 0,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildHeader(context, state),
              Expanded(child: _buildChatArea(context, state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BotChatState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // CP: Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Bot Chat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _buildActiveIndicator(context, state),
              const SizedBox(width: 8),
              _buildControlButton(context, state),
            ],
          ),
          if (state.isActive) ...[
            const SizedBox(height: 8),
            _buildActiveBotsRow(context, state),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveIndicator(BuildContext context, BotChatState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: state.isActive ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          state.isActive ? 'Active' : 'Inactive',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton(BuildContext context, BotChatState state) {
    return IconButton(
      onPressed: () {
        if (state.isActive) {
          context.read<BotChatCubit>().stopBotChat();
        } else {
          context.read<BotChatCubit>().startBotChat();
        }
      },
      icon: Icon(
        state.isActive ? Icons.pause : Icons.play_arrow,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: state.isActive ? 'Stop Bot Chat' : 'Start Bot Chat',
    );
  }

  Widget _buildActiveBotsRow(BuildContext context, BotChatState state) {
    return Wrap(
      spacing: 8,
      children:
          state.activePersonalities.map((personality) {
            final isTyping = state.currentlyTyping == personality;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                    isTyping
                        ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.2)
                        : Theme.of(
                          context,
                        ).colorScheme.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(personality.emoji, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    personality.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight:
                          isTyping ? FontWeight.bold : FontWeight.normal,
                      color:
                          isTyping
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isTyping) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildChatArea(BuildContext context, BotChatState state) {
    if (state.messages.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length,
      itemBuilder: (context, index) {
        final message = state.messages[index];
        return _buildMessageBubble(context, message);
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No bot conversations yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the play button to start the bot chat!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, BotMessage message) {
    final timeFormatter = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CP: Bot avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getBotColor(
                message.botPersonality,
              ).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                message.botPersonality.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // CP: Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CP: Bot name and timestamp
                Row(
                  children: [
                    Text(
                      message.botPersonality.displayName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getBotColor(message.botPersonality),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeFormatter.format(message.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // CP: Message text
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    message.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // CP: Get unique color for each bot personality
  Color _getBotColor(BotPersonality personality) {
    switch (personality) {
      case BotPersonality.statsBot:
        return Colors.blue;
      case BotPersonality.concernBot:
        return Colors.purple;
      case BotPersonality.chaosBot:
        return Colors.orange;
      case BotPersonality.coachBot:
        return Colors.green;
      case BotPersonality.memoryBot:
        return Colors.indigo;
    }
  }
}
