import 'package:flutter/widgets.dart';
import '../entry/repository/entry_repository.dart';
import 'logger.dart';

/// Monitors app lifecycle events to handle background processing.
///
/// When the app is paused (backgrounded), any pending entry processing will
/// attempt to complete within iOS's ~30 second background window.
/// When the app resumes, any entries that failed to process will be retried.
class AppLifecycleObserver with WidgetsBindingObserver {
  final EntryRepository _entryRepository;
  bool _isRegistered = false;

  AppLifecycleObserver({required EntryRepository entryRepository})
      : _entryRepository = entryRepository;

  /// Registers this observer with the widgets binding.
  /// Call this during app initialization.
  void register() {
    if (!_isRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _isRegistered = true;
      AppLogger.info('AppLifecycleObserver: Registered');
    }
  }

  /// Unregisters this observer from the widgets binding.
  /// Call this during app disposal.
  void unregister() {
    if (_isRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _isRegistered = false;
      AppLogger.info('AppLifecycleObserver: Unregistered');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // App is backgrounding - processing will continue within iOS's ~30s window
        AppLogger.info('AppLifecycleObserver: App paused/inactive - background processing may continue');
        break;

      case AppLifecycleState.resumed:
        // App is foregrounding - check for any pending entries that need retry
        AppLogger.info('AppLifecycleObserver: App resumed - checking for pending entries');
        _entryRepository.retryPendingEntries();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is terminating or hidden - nothing to do
        AppLogger.info('AppLifecycleObserver: App detached/hidden');
        break;
    }
  }
}
