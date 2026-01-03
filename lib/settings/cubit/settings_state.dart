part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  final AuthUser? currentUser;
  final bool isLoading;
  final bool isSigningIn;
  final bool isSigningOut;
  final String? errorMessage;

  const SettingsState({
    this.currentUser,
    this.isLoading = false,
    this.isSigningIn = false,
    this.isSigningOut = false,
    this.errorMessage,
  });

  bool get isAuthenticated => currentUser != null;

  SettingsState copyWith({
    AuthUser? currentUser,
    bool? isLoading,
    bool? isSigningIn,
    bool? isSigningOut,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return SettingsState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      isLoading: isLoading ?? this.isLoading,
      isSigningIn: isSigningIn ?? this.isSigningIn,
      isSigningOut: isSigningOut ?? this.isSigningOut,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [currentUser, isLoading, isSigningIn, isSigningOut, errorMessage];
}
