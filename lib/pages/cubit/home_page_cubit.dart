import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myapp/chat/chat.dart'; // Added import for ChatCubit
import 'package:myapp/utils/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page_state.dart';

class HomePageCubit extends Cubit<HomePageState> {
  static const String _lastShownVersionKey = 'last_shown_whats_new_version';
  final int _targetTapCount = 7; // Easter egg target

  final ChatCubit chatCubit;
  final ScrollController entriesScrollController = ScrollController();

  HomePageCubit({required this.chatCubit}) : super(const HomePageState()) {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await loadVersionInfo();
    await _loadLastSeenVersion();
    await checkWhatsNew();
    chatCubit.loadDummyMessages();
  }

  Future<void> _loadLastSeenVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenVersion = prefs.getString(_lastShownVersionKey);
      emit(state.copyWith(lastSeenVersion: lastSeenVersion));
    } catch (e, stackTrace) {
      AppLogger.error('Error loading last seen version: $e', stackTrace: stackTrace);
    }
  }

  Future<void> loadVersionInfo() async {
    if (state.appVersion.isNotEmpty || state.isVersionLoading) return;

    emit(state.copyWith(isVersionLoading: true));
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final versionString = 'v${info.version} (${info.buildNumber})';
      emit(state.copyWith(appVersion: versionString, isVersionLoading: false));
      AppLogger.info('App version loaded: $versionString');
    } catch (e, stackTrace) {
      AppLogger.error('Error loading package info: $e', stackTrace: stackTrace);
      emit(state.copyWith(isVersionLoading: false));
    }
  }

  Future<void> checkWhatsNew() async {
    if (state.appVersion.isEmpty) {
      AppLogger.log('checkWhatsNew called before appVersion was loaded. Retrying after delay.');
      await Future.delayed(const Duration(milliseconds: 100));
      if (state.appVersion.isEmpty) {
        AppLogger.error('checkWhatsNew failed: appVersion still empty after delay.');
        return;
      }
    }

    final currentVersion = state.appVersion.startsWith('v') ? state.appVersion.substring(1) : state.appVersion;
    final lastSeen = state.lastSeenVersion;

    if (lastSeen != currentVersion) {
      AppLogger.info('New version detected ($currentVersion). Triggering What\'s New dialog.');
      emit(state.copyWith(showWhatsNewDialog: true));
    } else {
      if (state.showWhatsNewDialog) {
        emit(state.copyWith(showWhatsNewDialog: false));
      }
    }
  }

  Future<void> markWhatsNewShown() async {
    final currentVersion = state.appVersion.startsWith('v') ? state.appVersion.substring(1) : state.appVersion;

    if (currentVersion.isEmpty) {
      AppLogger.error('Cannot mark What\'s New shown: currentVersion is empty.');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastShownVersionKey, currentVersion);
      emit(state.copyWith(showWhatsNewDialog: false, lastSeenVersion: currentVersion));
      AppLogger.info('Marked What\'s New as shown for version $currentVersion.');
    } catch (e, stackTrace) {
      AppLogger.error('Error saving last seen version: $e', stackTrace: stackTrace);
      emit(state.copyWith(showWhatsNewDialog: false));
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
      newCount = 0;
    } else if (newCount > _targetTapCount / 2 && newCount < _targetTapCount) {
      snackBarMsg = '${_targetTapCount - newCount} taps remaining...';
    } else if (newCount > _targetTapCount) {
      newCount = 0;
    }

    emit(
      state.copyWith(titleTapCount: newCount, snackBarMessage: snackBarMsg, clearSnackBarMessage: snackBarMsg == null),
    );
  }

  void clearSnackBarMessage() {
    if (state.snackBarMessage != null) {
      emit(state.copyWith(clearSnackBarMessage: true));
    }
  }

  void toggleChatOpen() {
    final wasOpen = state.isChatOpen;
    AppLogger.info('toggleChatOpen: changing from $wasOpen to ${!wasOpen}');
    emit(state.copyWith(isChatOpen: !state.isChatOpen));
    AppLogger.info('toggleChatOpen: state updated, new isChatOpen: ${state.isChatOpen}');
  }

  @override
  Future<void> close() {
    entriesScrollController.dispose();
    return super.close();
  }
}
