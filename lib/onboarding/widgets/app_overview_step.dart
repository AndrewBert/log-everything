import 'package:flutter/material.dart';

class AppOverviewStep extends StatelessWidget {
  const AppOverviewStep({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'How Log Splitter Works',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildHowItWorksStep(
              context,
              stepNumber: 1,
              icon: Icons.edit,
              title: 'Log Your Thoughts',
              description:
                  'Type or speak your thoughts, ideas, or daily activities. You can log multiple things at once.',
              example:
                  '"Went to the gym, had lunch with Sarah, need to call dentist"',
            ),
            const SizedBox(height: 24),
            _buildHowItWorksStep(
              context,
              stepNumber: 2,
              icon: Icons.auto_awesome,
              title: 'AI Splits & Categorizes',
              description:
                  'Our AI automatically splits your entry into separate items and assigns appropriate categories.',
              example:
                  '• "Went to the gym" → Exercise\n• "Had lunch with Sarah" → Personal\n• "Need to call dentist" → Health',
            ),
            const SizedBox(height: 24),
            _buildHowItWorksStep(
              context,
              stepNumber: 3,
              icon: Icons.chat,
              title: 'Chat with Your Logs',
              description:
                  'Ask questions about your past entries to gain insights and find information quickly.',
              example:
                  '"What did I do last week?" or "When was my last dentist appointment?"',
            ),
            const SizedBox(height: 40),
            _buildCallToAction(context),
            const SizedBox(height: 24), // CP: Added bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildHowItWorksStep(
    BuildContext context, {
    required int stepNumber,
    required IconData icon,
    required String title,
    required String description,
    required String example,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CP: Step number circle
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              stepNumber.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // CP: Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  example,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCallToAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'Ready to get started?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s set up your categories so the AI knows how to organize your entries.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
