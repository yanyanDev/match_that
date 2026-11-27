/// Keeping the screen awake while the Game page is open (spec §4d L3, L4).
library;

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Turns the device's screen-sleep off and on again. Injectable, so widget
/// tests can check it without the real plugin (they use a fake).
abstract interface class ScreenWakelock {
  /// Keeps the screen on until [disable] is called.
  Future<void> enable();

  /// Lets the screen sleep normally again.
  Future<void> disable();
}

/// The real wakelock, through the wakelock_plus plugin.
///
/// A failure (e.g. a browser that refuses the Wake Lock API) isn't worth
/// stopping a game for: the screen just sleeps as usual. It's logged in debug
/// builds so it isn't silently lost while developing.
class PluginWakelock implements ScreenWakelock {
  const PluginWakelock();

  @override
  Future<void> enable() => _guard('enable', WakelockPlus.enable);

  @override
  Future<void> disable() => _guard('disable', WakelockPlus.disable);

  Future<void> _guard(String action, Future<void> Function() call) async {
    try {
      await call();
    } catch (error) {
      // kDebugMode is a compile-time constant: in release builds this whole
      // block is removed. (debugPrint alone would still print in release.)
      if (kDebugMode) debugPrint('Wakelock $action failed: $error');
    }
  }
}
