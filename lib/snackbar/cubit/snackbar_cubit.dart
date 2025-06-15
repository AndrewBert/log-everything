import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/snackbar_message.dart';

part 'snackbar_state.dart';

class SnackbarCubit extends Cubit<SnackbarState> {
  SnackbarCubit() : super(const SnackbarState());

  void showSnackbar(SnackbarMessage message) {
    final updatedQueue = List<SnackbarMessage>.from(state.messageQueue)
      ..add(message);
    
    // If no message is currently showing, show this one immediately
    if (state.currentMessage == null) {
      emit(state.copyWith(
        currentMessage: message,
        messageQueue: updatedQueue.where((m) => m.id != message.id).toList(),
      ));
    } else {
      // Otherwise, add to queue
      emit(state.copyWith(messageQueue: updatedQueue));
    }
  }

  void removeSnackbar(String messageId) {
    if (state.currentMessage?.id == messageId) {
      // Remove current message and show next in queue
      _showNextInQueue();
    } else {
      // Remove from queue
      final updatedQueue = state.messageQueue
          .where((message) => message.id != messageId)
          .toList();
      emit(state.copyWith(messageQueue: updatedQueue));
    }
  }

  void _showNextInQueue() {
    if (state.messageQueue.isEmpty) {
      emit(state.copyWith(clearCurrentMessage: true));
    } else {
      final nextMessage = state.messageQueue.first;
      final updatedQueue = state.messageQueue.skip(1).toList();
      emit(state.copyWith(
        currentMessage: nextMessage,
        messageQueue: updatedQueue,
      ));
    }
  }

  void clearAllSnackbars() {
    emit(state.copyWith(clearCurrentMessage: true, messageQueue: []));
  }
}