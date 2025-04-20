import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'home_screen_state.dart';

class HomeScreenCubit extends Cubit<HomeScreenState> {
  HomeScreenCubit() : super(const HomeScreenState());

  final int _targetTapCount = 7; // Easter egg target

  Future<void> loadVersionInfo() async {
    if (state.appVersion.isNotEmpty || state.isVersionLoading) return;

    emit(state.copyWith(isVersionLoading: true));
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final versionString = 'v${info.version} (${info.buildNumber})';
      emit(state.copyWith(appVersion: versionString, isVersionLoading: false));
    } catch (e) {
      AppLogger.error('Failed to load version info', error: e);
      emit(state.copyWith(isVersionLoading: false)); // Ensure loading stops
    }
  }

  void setInputFocus(bool hasFocus) {
    if (hasFocus != state.isInputFocused) {
      emit(state.copyWith(isInputFocused: hasFocus));
    }
  }

  void incrementTitleTap() {
    int newCount = state.titleTapCount + 1;
    String? snackBarMsg;

    if (newCount == _targetTapCount) {
      snackBarMsg = '✨ You found the magic tap! ✨';
      newCount = 0; // Reset after success
    } else if (newCount > _targetTapCount / 2 && newCount < _targetTapCount) {
      snackBarMsg = '${_targetTapCount - newCount} taps remaining...';
    } else if (newCount > _targetTapCount) {
      // If somehow count goes beyond target without hitting exactly, reset
      newCount = 0;
    }

    emit(
      state.copyWith(
        titleTapCount: newCount,
        snackBarMessage: snackBarMsg,
        clearSnackBar: snackBarMsg == null, // Clear if no new message
      ),
    );
  }

  // Method to explicitly clear the snackbar message after it's shown
  void clearSnackBarMessage() {
    if (state.snackBarMessage != null) {
      emit(state.copyWith(clearSnackBar: true));
    }
  }
}
