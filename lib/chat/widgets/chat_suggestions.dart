import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/chat_cubit.dart';
import '../model/chat_suggestion.dart';

class ChatSuggestions extends StatelessWidget {
  final List<ChatSuggestion> suggestions;

  const ChatSuggestions({super.key, required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children:
            suggestions
                .map((suggestion) => _buildSuggestionChip(context, suggestion))
                .toList(),
      ),
    );
  }

  Widget _buildSuggestionChip(BuildContext context, ChatSuggestion suggestion) {
    return ActionChip(
      label: Text(
        suggestion.label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
      onPressed: () {
        context.read<ChatCubit>().addUserMessage(suggestion.query);
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
