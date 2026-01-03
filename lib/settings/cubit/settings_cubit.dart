import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/settings/services/auth_service.dart';
import 'package:myapp/utils/logger.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final AuthService _authService;
  StreamSubscription<AuthUser?>? _authSubscription;

  SettingsCubit({required AuthService authService})
      : _authService = authService,
        super(const SettingsState()) {
    _init();
  }

  void _init() {
    emit(state.copyWith(isLoading: true));

    // CP: Subscribe to auth state changes
    _authSubscription = _authService.authStateChanges.listen(
      (user) {
        emit(state.copyWith(
          currentUser: user,
          clearUser: user == null,
          isLoading: false,
        ));
      },
      onError: (error) {
        AppLogger.error('Auth state stream error', error: error);
        emit(state.copyWith(isLoading: false));
      },
    );

    // CP: Set initial user state
    final user = _authService.currentUser;
    emit(state.copyWith(
      currentUser: user,
      clearUser: user == null,
      isLoading: false,
    ));
  }

  Future<void> signInWithGoogle() async {
    try {
      emit(state.copyWith(isSigningIn: true, clearError: true));
      await _authService.signInWithGoogle();
      emit(state.copyWith(isSigningIn: false));
    } on AuthCancelledException {
      emit(state.copyWith(isSigningIn: false));
      AppLogger.info('User cancelled sign in');
    } on AuthException catch (e) {
      emit(state.copyWith(isSigningIn: false, errorMessage: e.message));
    } catch (e) {
      AppLogger.error('Unexpected sign in error', error: e);
      emit(state.copyWith(isSigningIn: false, errorMessage: 'An unexpected error occurred'));
    }
  }

  Future<void> signOut() async {
    try {
      emit(state.copyWith(isSigningOut: true, clearError: true));
      await _authService.signOut();
      emit(state.copyWith(isSigningOut: false));
    } on AuthException catch (e) {
      emit(state.copyWith(isSigningOut: false, errorMessage: e.message));
    } catch (e) {
      AppLogger.error('Unexpected sign out error', error: e);
      emit(state.copyWith(isSigningOut: false, errorMessage: 'Sign out failed'));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }
}
