import 'package:flutter/material.dart';

class WhatsNewDialog extends StatelessWidget {
  final String currentVersion;

  const WhatsNewDialog({super.key, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    final List<Widget> changes = [
      _buildChangeItem(
        '💬 Feature: Chat',
        'You can now interact with the assistant in a conversational way! Ask questions about your logs and get insights.',
      ),
      _buildChangeItem(
        '🤖 Log Splitting Improvements',
        'The assistant now processes your entries into more bite-sized, bullet-point style logs. If you submit a long entry, expect it to be split into several smaller logs. This is experimental and we welcome your feedback!',
      ),
      _buildChangeItem(
        '🔧 Bug Fixes',
        'Various bug fixes and performance improvements to enhance your experience.',
      ),
    ];

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
