// Simulated app lifecycle changes for widget tests (step 9, §4d L1, L2).
//
// The real platform always passes through the states in between
// (resumed ⇄ inactive ⇄ hidden ⇄ paused), and AppLifecycleListener asserts
// that it does. These helpers step from the binding's current state to the
// target one by one, the way a phone would.
//
// No tearDown needed: flutter_test resets the lifecycle state after each
// test.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _order = [
  AppLifecycleState.resumed,
  AppLifecycleState.inactive,
  AppLifecycleState.hidden,
  AppLifecycleState.paused,
];

/// Steps the app's lifecycle state to [target], one state at a time, and
/// draws the result.
Future<void> lifecycleTo(WidgetTester tester, AppLifecycleState target) async {
  final binding = tester.binding;
  // Before the first change of a test the state is null: the app just
  // started, in the foreground.
  if (binding.lifecycleState == null) {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }
  var at = _order.indexOf(binding.lifecycleState!);
  final to = _order.indexOf(target);
  while (at != to) {
    at += at < to ? 1 : -1;
    binding.handleAppLifecycleStateChanged(_order[at]);
  }
  await tester.pumpAndSettle();
}

/// A brief overlay where the game stays visible: notification shade, iOS
/// Control Center, browser window losing focus (inactive only).
Future<void> showOverlay(WidgetTester tester) =>
    lifecycleTo(tester, AppLifecycleState.inactive);

/// Home button, app switch, screen lock, tab hidden: the app goes out of
/// sight (inactive → hidden → paused).
Future<void> leaveApp(WidgetTester tester) =>
    lifecycleTo(tester, AppLifecycleState.paused);

/// Back in the foreground (paused → hidden → inactive → resumed).
Future<void> returnToApp(WidgetTester tester) =>
    lifecycleTo(tester, AppLifecycleState.resumed);
