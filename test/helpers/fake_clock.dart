import 'package:match_that/cubits/game_clock.dart';

/// A [GameClock] that only moves when a test says so.
///
/// There is no real time and no waiting: `elapse(ms(137))` calls the
/// listener with exactly 137 ms, synchronously. Like a real stopped clock,
/// it does nothing while stopped, so elapsing during a pause proves both
/// that the Cubit stopped the clock and that nothing was emitted.
class FakeClock implements GameClock {
  void Function(Duration elapsed)? _onTick;

  /// How many times the clock went from stopped to running.
  int starts = 0;

  @override
  bool get isRunning => _onTick != null;

  @override
  void start(void Function(Duration elapsed) onTick) {
    if (isRunning) return;
    _onTick = onTick;
    starts++;
  }

  @override
  void stop() => _onTick = null;

  /// Sends one tick of [time], if running.
  void elapse(Duration time) => _onTick?.call(time);
}
