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
        '✨ Feature: Quick Category Change',
        'Tap the category chip on any entry in the list to quickly reassign it to a different category.',
      ),
      _buildChangeItem(
        '✨ Feature: Edit Entries & Categories',
        'You can now edit the text of existing entries and rename your custom categories via the "Manage Categories" screen.',
      ),
      _buildChangeItem(
        '✨ Feature: Help & About Section',
        'Added a Help/About section (via the ? icon in the app bar) explaining the app and providing a way to view this "What\'s New" screen again.',
      ),
      _buildChangeItem(
        '✨ Feature: Haptic Feedback',
        'Added subtle vibrations for interactions like changing categories or managing them, enhancing the tactile feel of the app.',
      ),
      _buildChangeItem(
        '⚙️ Improvement: Voice Logging',
        'Improved the reliability and responsiveness of voice input for logging entries.',
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
