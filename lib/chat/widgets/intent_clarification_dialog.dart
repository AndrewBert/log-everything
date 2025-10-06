import 'package:flutter/material.dart';
import 'package:myapp/utils/chat_keys.dart';

class IntentClarificationDialog extends StatelessWidget {
  final String userInput;
  final VoidCallback onNoteSelected;
  final VoidCallback onChatSelected;

  const IntentClarificationDialog({
    super.key,
    required this.userInput,
    required this.onNoteSelected,
    required this.onChatSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: ChatKeys.intentClarificationDialog,
      title: const Text('What would you like to do?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your input is:'),
          const SizedBox(height: 8),
          Text(
            '"$userInput"',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          const Text('Would you like to log this as a note or start a chat?'),
        ],
      ),
      actions: [
        TextButton.icon(
          key: ChatKeys.intentClarificationNoteButton,
          icon: const Icon(Icons.edit_note),
          label: const Text('Log as Note'),
          onPressed: onNoteSelected,
        ),
        TextButton.icon(
          key: ChatKeys.intentClarificationChatButton,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Start Chat'),
          onPressed: onChatSelected,
        ),
      ],
    );
  }
}
