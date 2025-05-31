import 'package:flutter/material.dart';

class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // CP: Added SingleChildScrollView to handle overflow
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // CP: App logo/icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                Icons.edit_note,
                size: 60,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            // CP: Welcome title
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: Theme.of(context).textTheme.headlineMedium,
                children: [
                  TextSpan(
                    text: 'Welcome to ',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.headlineMedium?.color,
                    ),
                  ),
                  TextSpan(
                    text: 'Log',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' Splitter',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.headlineMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // CP: Welcome description
            Text(
              'Your intelligent logging companion that helps you capture thoughts, organize them automatically, and chat with your memories.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            // CP: Features preview
            _buildFeaturesList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context) {
    final features = [
      {
        'icon': Icons.auto_awesome,
        'title': 'Smart Logging',
        'description': 'AI automatically categorizes your entries',
      },
      {
        'icon': Icons.chat_bubble_outline,
        'title': 'Chat with Logs',
        'description': 'Ask questions about your past entries',
      },
      {
        'icon': Icons.category_outlined,
        'title': 'Custom Categories',
        'description': 'Organize entries your way',
      },
    ];

    return Column(
      children:
          features.map((feature) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      feature['icon'] as IconData,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          feature['title'] as String,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          feature['description'] as String,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}
