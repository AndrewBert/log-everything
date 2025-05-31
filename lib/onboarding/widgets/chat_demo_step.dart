import 'package:flutter/material.dart';

class ChatDemoStep extends StatelessWidget {
  const ChatDemoStep({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              'Chat with Your Logs',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Once you have some entries, you can chat with your logs to find insights and information quickly.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildChatExample(context),
            const SizedBox(height: 32),
            _buildHowToAccess(context),
            const SizedBox(height: 32),
            _buildCompletionMessage(context),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChatExample(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue[50] ?? Colors.blue[100]!,
            Colors.blue[50]?.withValues(alpha: 0.5) ?? Colors.blue[100]!.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200] ?? Colors.blue[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline,
                color: Colors.blue[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Example Chat Conversation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildChatBubble(
            context,
            'You: "What have I been doing for exercise this month?"',
            isUser: true,
          ),
          const SizedBox(height: 12),
          _buildChatBubble(
            context,
            'AI: "Based on your logs, you\'ve been quite active! You went to the gym 8 times, went running 3 times, and did yoga twice. Your most frequent workout days are Monday, Wednesday, and Friday."',
            isUser: false,
          ),
          const SizedBox(height: 12),
          _buildChatBubble(
            context,
            'You: "When did I last see Dr. Smith?"',
            isUser: true,
          ),
          const SizedBox(height: 12),
          _buildChatBubble(
            context,
            'AI: "You had an appointment with Dr. Smith on March 15th. You mentioned it was a routine checkup and everything looked good."',
            isUser: false,
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
    BuildContext context,
    String message, {
    required bool isUser,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUser ? Theme.of(context).colorScheme.primary : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isUser ? Colors.white : Colors.black87,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildHowToAccess(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.touch_app,
            color: Theme.of(context).colorScheme.primary,
            size: 32,
          ),
          const SizedBox(height: 12),
          Text(
            'How to Access Chat',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Look for the chat icon in the bottom-left corner of your home screen. Tap it to start chatting with your logs!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionMessage(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green[50] ?? Colors.green[100]!,
            Colors.green[50]?.withValues(alpha: 0.5) ?? Colors.green[100]!.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200] ?? Colors.green[300]!),
      ),
      child: Column(
        children: [
          Icon(Icons.celebration, color: Colors.green[700], size: 32),
          const SizedBox(height: 12),
          Text(
            'You\'re All Set!',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.green[700],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re ready to start using Log Splitter! Begin by logging your first entry and watch the AI work its magic.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.green[700],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
