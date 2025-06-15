import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum SnackbarType {
  success,
  error,
  warning,
  info,
}

enum SnackbarContext {
  home,
  chat,
  dialog,
  global,
}

class SnackbarMessage extends Equatable {
  const SnackbarMessage({
    required this.id,
    required this.message,
    required this.type,
    this.context = SnackbarContext.global,
    this.actionLabel,
    this.onActionPressed,
    this.duration = const Duration(seconds: 4),
  });

  final String id;
  final String message;
  final SnackbarType type;
  final SnackbarContext context;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Duration duration;

  @override
  List<Object?> get props => [id, message, type, context, actionLabel, duration];

  SnackbarMessage copyWith({
    String? id,
    String? message,
    SnackbarType? type,
    SnackbarContext? context,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
  }) {
    return SnackbarMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      context: context ?? this.context,
      actionLabel: actionLabel ?? this.actionLabel,
      onActionPressed: onActionPressed ?? this.onActionPressed,
      duration: duration ?? this.duration,
    );
  }
}