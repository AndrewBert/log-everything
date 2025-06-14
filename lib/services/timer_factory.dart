import 'dart:async';

/// Abstract factory for creating timers, allowing different implementations for production and testing.
abstract class TimerFactory {
  /// Creates a timer that executes the callback after the specified duration.
  Timer createTimer(Duration duration, void Function() callback);
}

/// Production implementation that creates real timers.
class RealTimerFactory implements TimerFactory {
  @override
  Timer createTimer(Duration duration, void Function() callback) {
    return Timer(duration, callback);
  }
}

/// Test implementation that executes callbacks immediately without delays.
class TestTimerFactory implements TimerFactory {
  @override
  Timer createTimer(Duration duration, void Function() callback) {
    // Execute callback immediately in tests to avoid timer-related test failures
    Timer.run(callback);
    // Return a completed timer that can be cancelled safely
    return Timer(Duration.zero, () {});
  }
}