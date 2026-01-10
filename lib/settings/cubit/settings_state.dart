part of 'settings_cubit.dart';

/// CP: Holds information about a recoverable snapshot when data loss is detected.
class RecoveryInfo extends Equatable {
  final int entryCount;
  final int categoryCount;
  final DateTime snapshotCreatedAt;

  const RecoveryInfo({
    required this.entryCount,
    required this.categoryCount,
    required this.snapshotCreatedAt,
  });

  @override
  List<Object?> get props => [entryCount, categoryCount, snapshotCreatedAt];
}

class SettingsState extends Equatable {
  final AuthUser? currentUser;
  final bool isLoading;
  final bool isSigningIn;
  final bool isSigningOut;
  final String? errorMessage;
  // CP: Recovery info when data loss is detected after sign-in
  final RecoveryInfo? recoveryInfo;
  final bool isRecovering;

  const SettingsState({
    this.currentUser,
    this.isLoading = false,
    this.isSigningIn = false,
    this.isSigningOut = false,
    this.errorMessage,
    this.recoveryInfo,
    this.isRecovering = false,
  });

  bool get isAuthenticated => currentUser != null;
  bool get hasRecoveryAvailable => recoveryInfo != null;

  SettingsState copyWith({
    AuthUser? currentUser,
    bool? isLoading,
    bool? isSigningIn,
    bool? isSigningOut,
    String? errorMessage,
    RecoveryInfo? recoveryInfo,
    bool? isRecovering,
    bool clearUser = false,
    bool clearError = false,
    bool clearRecovery = false,
  }) {
    return SettingsState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      isSigningIn: isSigningIn ?? this.isSigningIn,
      isSigningOut: isSigningOut ?? this.isSigningOut,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      recoveryInfo: clearRecovery ? null : (recoveryInfo ?? this.recoveryInfo),
      isRecovering: isRecovering ?? this.isRecovering,
    );
  }

  @override
  List<Object?> get props => [currentUser, isLoading, isSigningIn, isSigningOut, errorMessage, recoveryInfo, isRecovering];
}
