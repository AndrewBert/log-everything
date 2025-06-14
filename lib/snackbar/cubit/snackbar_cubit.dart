import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/snackbar_message.dart';

part 'snackbar_state.dart';

class SnackbarCubit extends Cubit<SnackbarState> {
  SnackbarCubit() : super(const SnackbarState());

  void showSnackbar(SnackbarMessage message) {
    final updatedMessages = List<SnackbarMessage>.from(state.messages)
      ..add(message);
    emit(state.copyWith(messages: updatedMessages));
  }

  void removeSnackbar(String messageId) {
    final updatedMessages = state.messages
        .where((message) => message.id != messageId)
        .toList();
    emit(state.copyWith(messages: updatedMessages));
  }

  void clearAllSnackbars() {
    emit(state.copyWith(messages: []));
  }
}