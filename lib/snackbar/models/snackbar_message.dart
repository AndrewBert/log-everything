import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum SnackbarType {
  success,
  error,
  warning,
  info,
}

class SnackbarMessage extends Equatable {
  const SnackbarMessage({
    required this.id,
    required this.message,
    required this.type,
    this.actionLabel,
    this.onActionPressed,
    this.duration = const Duration(seconds: 4),
  });

  final String id;
  final String message;
  final SnackbarType type;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final Duration duration;

  @override
  List<Object?> get props => [id, message, type, actionLabel, duration];

  SnackbarMessage copyWith({
    String? id,
    String? message,
    SnackbarType? type,
    String? actionLabel,
    VoidCallback? onActionPressed,
    Duration? duration,
  }) {
    return SnackbarMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      type: type ?? this.type,
      actionLabel: actionLabel ?? this.actionLabel,
      onActionPressed: onActionPressed ?? this.onActionPressed,
      duration: duration ?? this.duration,
    );
  }
}