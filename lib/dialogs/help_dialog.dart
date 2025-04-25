import 'package:flutter/material.dart';

class HelpDialog extends StatelessWidget {
  final VoidCallback onShowWhatsNewPressed;

  const HelpDialog({super.key, required this.onShowWhatsNewPressed});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: 8),
          Text('About Log Splitter'),
        ],
      ),
      content: const SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Motivation:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'This app helps you quickly capture thoughts, tasks, or events using voice or text, automatically categorizing them for easy review later.',
            ),
            SizedBox(height: 12),
            Text(
              'Purpose & Key Features:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text(
              '- Log entries via text input or voice dictation.\n'
              '- Automatic categorization using AI (powered by OpenAI).\n'
              '- View entries grouped by date.\n'
              '- Filter entries by category.\n'
              '- Manage custom categories.\n'
              '- Edit or delete existing entries.',
            ),
            SizedBox(height: 12),
            Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text(
              'Your feedback is valuable! Please report any bugs, suggest improvements, or share your experience, especially regarding:\n'
              '- Accuracy of voice transcription.\n'
              '- Relevance of AI categorization.\n'
              '- Overall usability and workflow.',
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close help dialog first
            onShowWhatsNewPressed(); // Call the callback
          },
          child: const Text("What's New"),
        ),
        TextButton(
          child: const Text('Close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
