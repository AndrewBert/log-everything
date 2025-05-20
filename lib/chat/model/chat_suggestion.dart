import 'package:equatable/equatable.dart';

/// Represents a suggested action in the chat interface
class ChatSuggestion extends Equatable {
  final String id;
  final String label;
  final String query;
  final String? icon;

  const ChatSuggestion({
    required this.id,
    required this.label,
    required this.query,
    this.icon,
  });

  @override
  List<Object?> get props => [id, label, query, icon];
}

/// Default suggestions that can be shown to the user
class DefaultSuggestions {
  static const List<ChatSuggestion> suggestions = [
    ChatSuggestion(
      id: 'summarize_today',
      label: 'Summarize today\'s entries',
      query: 'Can you summarize my entries from today?',
    ),
    ChatSuggestion(
      id: 'recent_patterns',
      label: 'Find recent patterns',
      query: 'What patterns do you notice in my recent entries?',
    ),
    ChatSuggestion(
      id: 'most_active',
      label: 'Most active categories',
      query: 'Which categories have I used the most?',
    ),
    ChatSuggestion(
      id: 'search_help',
      label: 'How to search effectively',
      query: 'What are some tips for searching through my entries effectively?',
    ),
  ];
}
