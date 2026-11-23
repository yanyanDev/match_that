/// The clock that drives a game's time (spec §4c A1).
library;

import 'dart:async';

/// Sends the time that passed to a listener while it runs. Injectable, so
/// tests can drive time without waiting (they use a fake).
abstract interface class GameClock {
  bool get isRunning;

  /// Starts sending [onTick] the time elapsed since the previous tick (or
  /// since start). Does nothing if already running.
  void start(void Function(Duration elapsed) onTick);

  /// Stops sending ticks. The time since the last tick is not sent (A1).
  /// Does nothing if already stopped.
  void stop();
}

/// The real clock: a [Timer] fires every [interval], and a [Stopwatch]
/// measures how much time actually passed, because a timer can fire late.
class PeriodicClock implements GameClock {
  PeriodicClock({this.interval = const Duration(milliseconds: 100)});

  final Duration interval;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  Duration _lastReading = Duration.zero;

  @override
  bool get isRunning => _timer != null;

  @override
  void start(void Function(Duration elapsed) onTick) {
    if (isRunning) return;
    // A fresh measurement: time spent stopped is never counted.
    _stopwatch
      ..reset()
      ..start();
    _lastReading = Duration.zero;
    _timer = Timer.periodic(interval, (_) {
      final now = _stopwatch.elapsed;
      final elapsed = now - _lastReading;
      _lastReading = now;
      onTick(elapsed);
    });
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
    _stopwatch.stop();
  }
}
