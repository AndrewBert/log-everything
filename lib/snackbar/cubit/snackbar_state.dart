part of 'snackbar_cubit.dart';

class SnackbarState extends Equatable {
  const SnackbarState({
    this.messages = const [],
  });

  final List<SnackbarMessage> messages;

  @override
  List<Object> get props => [messages];

  SnackbarState copyWith({
    List<SnackbarMessage>? messages,
  }) {
    return SnackbarState(
      messages: messages ?? this.messages,
    );
  }
}