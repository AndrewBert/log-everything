import 'package:flutter/foundation.dart';

/// A simple logger utility that only logs in debug mode.
///
/// Usage:
/// ```dart
/// AppLogger.log('This is a regular message');
/// AppLogger.error('Something went wrong', error: exception, stackTrace: stackTrace);
/// AppLogger.info('Operation completed successfully');
/// AppLogger.warning('This might be an issue.');
/// AppLogger.startupBegin(); // Call at start of main()
/// AppLogger.startup('Phase completed'); // Log startup phases
/// AppLogger.startupComplete(); // Call after initialization
/// ```
class AppLogger {
  // CP: Stopwatch for tracking startup timing
  static final _startupStopwatch = Stopwatch();

  /// Start the startup timer (call once at very beginning of main())
  static void startupBegin() {
    if (kDebugMode) {
      _startupStopwatch.start();
      debugPrint('STARTUP: Beginning app initialization');
    }
  }

  /// Log a startup phase with elapsed time
  static void startup(String phase) {
    if (kDebugMode) {
      debugPrint('STARTUP [${_startupStopwatch.elapsedMilliseconds}ms]: $phase');
    }
  }

  /// End startup timing and print summary
  static void startupComplete() {
    if (kDebugMode) {
      _startupStopwatch.stop();
      debugPrint('STARTUP: Complete in ${_startupStopwatch.elapsedMilliseconds}ms');
    }
  }

  /// Log a general message (only in debug mode)
  static void log(String message) {
    if (kDebugMode) {
      debugPrint('📝 LOG: $message');
    }
  }

  /// Log an error message with optional error and stack trace (only in debug mode)
  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('❌ ERROR: $message');
      if (error != null) {
        debugPrint('Error details: $error');
      }
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Log an info message (only in debug mode)
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ INFO: $message');
    }
  }

  /// Log a warning message (only in debug mode)
  static void warn(String message, {Object? error}) {
    // Added optional error parameter for consistency
    if (kDebugMode) {
      debugPrint('⚠️ WARNING: $message');
      if (error != null) {
        // Log error details if provided
        debugPrint('Warning details: $error');
      }
    }
  }

  static void debug(String s) {
    if (kDebugMode) {
      debugPrint('DEBUG: $s');
    }
  }
}
