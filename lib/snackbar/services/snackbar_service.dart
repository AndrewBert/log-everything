import 'package:flutter/material.dart';
import '../cubit/snackbar_cubit.dart';
import '../models/snackbar_message.dart';

class SnackbarService {
  SnackbarService(this._snackbarCubit);

  final SnackbarCubit _snackbarCubit;

  void showSuccess(String message, {SnackbarContext context = SnackbarContext.global, String? actionLabel, VoidCallback? onActionPressed}) {
    _showSnackbar(
      message: message,
      type: SnackbarType.success,
      context: context,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  void showError(String message, {SnackbarContext context = SnackbarContext.global, String? actionLabel, VoidCallback? onActionPressed}) {
    _showSnackbar(
      message: message,
      type: SnackbarType.error,
      context: context,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  void showWarning(String message, {SnackbarContext context = SnackbarContext.global, String? actionLabel, VoidCallback? onActionPressed}) {
    _showSnackbar(
      message: message,
      type: SnackbarType.warning,
      context: context,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  void showInfo(String message, {SnackbarContext context = SnackbarContext.global, String? actionLabel, VoidCallback? onActionPressed}) {
    _showSnackbar(
      message: message,
      type: SnackbarType.info,
      context: context,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
    );
  }

  void _showSnackbar({
    required String message,
    required SnackbarType type,
    SnackbarContext context = SnackbarContext.global,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
  }) {
    final snackbarMessage = SnackbarMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: type,
      context: context,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      duration: duration ?? const Duration(seconds: 4),
    );

    _snackbarCubit.showSnackbar(snackbarMessage);
  }

  void dismissSnackbar(String id) {
    _snackbarCubit.removeSnackbar(id);
  }

  void dismissAll() {
    _snackbarCubit.clearAllSnackbars();
  }
}