part of 'snackbar_cubit.dart';

class SnackbarState extends Equatable {
  const SnackbarState({
    this.currentMessage,
    this.messageQueue = const [],
    this.messages = const [],
  });

  final SnackbarMessage? currentMessage;
  final List<SnackbarMessage> messageQueue;
  final List<SnackbarMessage> messages;

  @override
  List<Object?> get props => [currentMessage, messageQueue, messages];

  SnackbarState copyWith({
    SnackbarMessage? currentMessage,
    bool clearCurrentMessage = false,
    List<SnackbarMessage>? messageQueue,
    List<SnackbarMessage>? messages,
  }) {
    return SnackbarState(
      currentMessage: clearCurrentMessage ? null : (currentMessage ?? this.currentMessage),
      messageQueue: messageQueue ?? this.messageQueue,
      messages: messages ?? this.messages,
    );
  }
}