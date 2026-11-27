import 'package:match_that/screens/game/screen_wakelock.dart';

/// A [ScreenWakelock] that only records what it was asked to do. No plugin,
/// no platform channel: tests read [enabled], [enables] and [disables].
class FakeWakelock implements ScreenWakelock {
  /// Whether the screen would be kept awake right now.
  bool enabled = false;

  /// How many times [enable] / [disable] were called.
  int enables = 0;
  int disables = 0;

  @override
  Future<void> enable() async {
    enabled = true;
    enables++;
  }

  @override
  Future<void> disable() async {
    enabled = false;
    disables++;
  }
}
