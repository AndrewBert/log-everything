import 'package:flutter/material.dart';

class WhatsNewDialog extends StatelessWidget {
  final String currentVersion;

  const WhatsNewDialog({super.key, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    // --- Define your What's New content here ---
    // Keep this list concise, highlighting major changes.
    final List<Widget> _v140Changes = [
      _buildChangeItem(
        '📦 Category Archiving',
        '''Clean up your category list! Archive categories you're not using right now - they'll disappear from the main view but your entries stay safe. Unarchive anytime from the category settings.''',
      ),
      _buildChangeItem(
        '🔧 UI Improvements',
        '''Input bar now has a subtle border for better visibility. Search field behavior improved - tapping outside properly dismisses the keyboard.''',
      ),
    ];

    final List<Widget> _v131Changes = [
      _buildChangeItem(
        '📷 Image Attachments',
        '''Attach photos to any entry! Tap the attachment button to add images from your camera or photo library. Images appear as thumbnails on cards and in search results.''',
      ),
      _buildChangeItem(
        '💬 New Chat Look',
        '''Experimenting with a redesigned chat page interface. Let me know what you think!''',
      ),
    ];

    final List<Widget> _v130Changes = [
      _buildChangeItem(
        '🔍 Note Search',
        '''Find any note instantly! Search through all your entries by keyword - finally a way to find that thing you wrote last month.''',
      ),
      _buildChangeItem(
        '💬 AI Chat',
        '''Ask questions about your notes! Type something like "what did I log about work last week?" and get answers from your personal AI assistant. The input bar auto-detects when you're asking a question.''',
      ),
    ];

    final List<Widget> _v123Changes = [
      _buildChangeItem(
        '💾 Auto-save for note editing',
        '''Notes now save automatically when you navigate away - no more lost changes!''',
      ),
      _buildChangeItem(
        '✨ Simplified AI insights',
        '''Removed pattern detection while we rework it. Insights are now cleaner and more focused.''',
      ),
    ];

    final List<Widget> _v122Changes = [
      _buildChangeItem(
        '🚀 Upgraded to GPT-5',
        '''Switched from GPT-4 to GPT-5 (just released last week). Early testing shows it's better at understanding context, but we'll see how it performs in real use.''',
      ),
      _buildChangeItem(
        '🤖 Simplified AI instructions by 85%',
        '''Rewrote the AI prompt from scratch - went from 300+ lines to 40. It now acts as your personal note-taking assistant that follows your instructions: "make this a todo", "format as bullets", etc.''',
      ),
      _buildChangeItem(
        '✅ More conservative todo detection',
        '''The streamlined prompt is way more conservative. Only explicit actions become todos. Hopefully fewer false todos - let me know how it works for you!''',
      ),
      _buildChangeItem(
        '📁 Basic functionality that was missing',
        '''Todos are now tappable for details (finally!). Categories can be deleted and sort by recency. Just bringing these features up to par with the rest of the app.''',
      ),
    ];

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
              // Version 1.4.0 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.archive_outlined, color: Colors.indigo.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.4.0 - The Archive Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.indigo.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._v140Changes,
              const SizedBox(height: 20),
              // Version 1.3.1 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.camera_alt, color: Colors.pink.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.3.1 - The Image Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.pink.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._v131Changes,
              const SizedBox(height: 20),
              // Version 1.3.0 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.teal.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.3.0 - The Search Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._v130Changes,
              const SizedBox(height: 20),
              // Version 1.2.3 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.save_outlined, color: Colors.orange.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.2.3 - Quality of Life',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._v123Changes,
              const SizedBox(height: 20),
              // Version 1.2.2 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Colors.purple.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.2.2 - The AI Overhaul',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ..._v122Changes,
              const SizedBox(height: 20),
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
                        'v1.2.1 - Bug Fixes',
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
