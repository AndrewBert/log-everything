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
        '🎯 Streamlined Onboarding',
        '''The onboarding flow has been simplified and improved! We've removed redundant steps and updated the chat instructions to help you get started faster.''',
      ),
      _buildChangeItem(
        '🎨 UI Refresh',
        '''Fresh new look for entry cards with improved spacing, better typography, and cleaner visual hierarchy. The interface now feels more modern and polished.''',
      ),
      _buildChangeItem(
        '🏷️ Enhanced Filter Chips',
        '''Filter chips now have a sleek new design with better visual feedback and improved readability. Finding your entries has never looked this good!''',
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
      actions: <Widget>[TextButton(child: const Text('Got it!'), onPressed: () => Navigator.of(context).pop())],
    );
  }

  Widget _buildChangeItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 3),
          Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        ],
      ),
    );
  }
}
