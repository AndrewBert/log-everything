import 'package:flutter/material.dart';

class WhatsNewDialog extends StatelessWidget {
  final String currentVersion;

  const WhatsNewDialog({super.key, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    // --- Define your What's New content here ---
    // Keep this list concise, highlighting major changes.
    final List<Widget> _bugFixChanges = [
      _buildChangeItem(
        '🐛 UI Polish & Fixes',
        '''Fixed text visibility in floating input bar, improved carousel scrolling behavior, enhanced layout consistency, and resolved overflow issues in insight containers.''',
      ),
      _buildChangeItem(
        '🎯 Performance Improvements',
        '''Optimized AI insights with consistent model usage, removed unused dependencies, and improved color system consistency throughout the app.''',
      ),
    ];

    final List<Widget> _majorFeatureChanges = [
      _buildChangeItem(
        '📰 All-New Dashboard Experience',
        '''Completely redesigned home screen with a newspaper-inspired layout, AI-powered insights, and intuitive navigation.''',
      ),
      _buildChangeItem(
        '✨ Floating Smart Input',
        '''New floating input bar with voice transcription and seamless entry creation.''',
      ),
      _buildChangeItem(
        '🎯 Todo Management',
        '''Dedicated todo section and pages to track and complete your tasks. Todos are automatically filtered from your main entries.''',
      ),
      _buildChangeItem(
        '🎨 Personalized Categories',
        '''Enhanced category system with custom colors, better organization, and quick access to all your categorized entries.''',
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
            children: [
              // Version 1.2.1 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bug_report, color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.2.1 - The Polish Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._bugFixChanges,
              const SizedBox(height: 20),
              // Version 1.1.9 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.1.9 - The Dashboard Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._majorFeatureChanges,
              const SizedBox(height: 16),
              // CP: Personal message from developer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Hello it\'s Andrew 👋',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '''I've completely redesigned the app to hopefully show more valuable information and be more intuitive. I'm experimenting with the app's theme - trying a newspaper-style approach right now - and I really want your feedback!

Your input has been incredibly helpful in shaping this app. Please keep the feedback coming - it truly makes a difference.''',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
