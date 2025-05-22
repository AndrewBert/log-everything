import 'package:flutter/material.dart';

class WhatsNewDialog extends StatelessWidget {
  final String currentVersion;

  const WhatsNewDialog({super.key, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    // --- Define your What's New content here ---
    // Keep this list concise, highlighting major changes.
    final List<Widget> changes = [
      _buildChangeItem(
        '💬 Feature: Chat',
        '''Ask questions about your logs and get insights. Basically a virtual girlfriend that can help you with your logs. You're welcome.''',
      ),
      _buildChangeItem(
        '🤖 Log Splitting Improvements',
        '''No more annoying log splitting! I have fine-tuned it so it splits less and overall doesn't suck. This is experimental and I welcome your feedback.''',
      ),
      _buildChangeItem(
        '📝 Category Descriptions',
        'Have two similar categories? Despise when your entry gets misplaced? Despise no more! You can now add descriptions to your categories.',
      ),
      _buildChangeItem(
        '🔧 Bug Fixes',
        'Various bug fixes and performance improvements to enhance your experience.',
      ),
    ];
    // --- End of What's New content ---

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.new_releases_outlined, color: Colors.orangeAccent),
          const SizedBox(width: 10),
          Text("What's New in v$currentVersion"),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite, // Make dialog use available width
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: changes,
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Got it!'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildChangeItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
