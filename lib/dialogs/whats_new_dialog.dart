import 'package:flutter/material.dart';

class WhatsNewDialog extends StatelessWidget {
  final String currentVersion;

  const WhatsNewDialog({super.key, required this.currentVersion});

  @override
  Widget build(BuildContext context) {
    // --- Define your What's New content here ---
    // Keep this list concise, highlighting major changes.
    final List<Widget> v163Changes = [
      _buildChangeItem(
        '⚡ Faster Startup',
        '''The app now loads significantly faster for returning users — no more loading spinner on launch.''',
      ),
      _buildChangeItem(
        '🧠 Smarter Onboarding Detection',
        '''Returning users are recognized instantly via a lightweight cloud check, skipping unnecessary setup steps.''',
      ),
      _buildChangeItem(
        '🔧 Reduced Redundant Syncs',
        '''Startup sign-in is now optimized to avoid duplicate Firestore operations, making everything snappier.''',
      ),
    ];

    final List<Widget> v160Changes = [
      _buildChangeItem(
        '☁️ Cloud Storage & Sync',
        '''Your entries now live in the cloud! Data syncs automatically via Firestore — your logs are backed up and accessible across devices.''',
      ),
      _buildChangeItem(
        '🔐 Firebase Auth',
        '''Sign in with Apple or Google to secure your data. Anonymous accounts upgrade seamlessly — no data loss when you link a provider.''',
      ),
      _buildChangeItem(
        '✨ AI Rephrase Toggle',
        '''Control whether AI rephrases your entries. Toggle it off to keep your exact wording while still getting automatic categorization.''',
      ),
      _buildChangeItem(
        '🔗 Tappable URLs',
        '''Links in your entries are now tappable — tap to open them directly from the details page.''',
      ),
      _buildChangeItem(
        '🔄 Reliability Improvements',
        '''Retry queues, offline persistence, and paginated loading make the app faster and more reliable, even with spotty connectivity.''',
      ),
    ];

    final List<Widget> v150Changes = [
      _buildChangeItem(
        '📅 Category Calendar',
        '''View your entries on a calendar! See which days have entries, browse by date, and track your logging patterns over time.''',
      ),
      _buildChangeItem(
        '🔄 Note ↔ Todo Toggle',
        '''Changed your mind? Convert any note to a todo (or vice versa) with a single tap from the entry details page.''',
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
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Version 1.6.3 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.amber.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.6.3 - The Speed Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...v163Changes,
              const SizedBox(height: 20),
              // Version 1.6.0 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cloud_outlined, color: Colors.deepPurple.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.6.0 - The Cloud Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...v160Changes,
              const SizedBox(height: 20),
              // Version 1.5.0 Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyan.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, color: Colors.cyan.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'v1.5.0 - The Calendar Update',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.cyan.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...v150Changes,
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
