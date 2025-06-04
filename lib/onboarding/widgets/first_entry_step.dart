import 'package:flutter/material.dart';

class FirstEntryStep extends StatelessWidget {
  const FirstEntryStep({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              'Try Your First Entry',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Let\'s see the AI in action! Try logging something with multiple activities.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildExampleCard(
              context,
              title: 'Example Entry',
              content: 'Had breakfast with mom, went shopping for groceries, called the bank about my account',
              icon: Icons.lightbulb_outline,
            ),
            const SizedBox(height: 24),
            _buildExampleCard(
              context,
              title: 'AI Will Split This Into',
              content:
                  '• "Had breakfast with mom" → Family\n• "Went shopping for groceries" → Personal\n• "Called the bank about my account" → Finance',
              icon: Icons.auto_awesome,
              isResult: true,
            ),
            const SizedBox(height: 40),
            _buildTryItSection(context),
            const SizedBox(height: 24),
            _buildHelpText(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    bool isResult = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isResult ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isResult ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: isResult ? Theme.of(context).colorScheme.primary : Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isResult ? Theme.of(context).colorScheme.primary : Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.4, fontStyle: isResult ? FontStyle.normal : FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildTryItSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.edit_note, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Ready to try it?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'After completing setup, you\'ll see the input area at the bottom of your home screen. Just start typing or tap the microphone!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700], height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpText(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Pro tip: You can log multiple activities in one entry and the AI will split them automatically!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.blue[700]),
            ),
          ),
        ],
      ),
    );
  }
}
