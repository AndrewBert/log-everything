import 'package:equatable/equatable.dart';

enum ChatSender { user, ai }

class ChatMessage extends Equatable {
  final String id;
  final String text;
  final ChatSender sender;
  final DateTime timestamp;

  const ChatMessage({required this.id, required this.text, required this.sender, required this.timestamp});

  @override
  List<Object?> get props => [id, text, sender, timestamp];
}
