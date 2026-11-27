// Shared helpers for the Game screen widget tests (step 8b).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/game_cubit.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/screens/game/screen_wakelock.dart';
import 'package:match_that/ui/app_theme.dart';

import 'fake_clock.dart';
import 'fake_random.dart';
import 'fake_wakelock.dart';
import 'game_helpers.dart';

/// The text on the page under the Game screen, so tests can see when Back
/// left the game.
const belowGame = 'PAGE BELOW THE GAME';

/// Shows a GameScreen for a new game on a phone-sized screen, pushed on top
/// of a plain page (like Home), so system Back has somewhere to go.
///
/// Uses a real GameCubit with a FakeClock and ZeroRandom: seat 0 (P1)
/// starts and tricks come out in order (t0, t1, ...), each worth 1 point.
/// Returns the Cubit (to check what a tap did) and the clock (to move time).
///
/// A [FakeWakelock] is provided above MaterialApp, where the app provides the
/// real one (L4). Pass your own [wakelock] to check what the screen did.
Future<(GameCubit, FakeClock)> pumpGame(
  WidgetTester tester, {
  GameConfig? config,
  List<Player>? players,
  ScreenWakelock? wakelock,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final clock = FakeClock();
  final cubit = GameCubit(
    config: config ?? timed(target: 2),
    players: players ?? makePlayers(2),
    library: equalLibrary(6),
    random: ZeroRandom(),
    clock: clock,
  );
  addTearDown(cubit.close);

  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    // RepositoryProvider: like BlocProvider, but for any plain object.
    RepositoryProvider<ScreenWakelock>.value(
      value: wakelock ?? FakeWakelock(),
      child: MaterialApp(
        navigatorKey: navigator,
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: Text(belowGame))),
      ),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      // BlocProvider.value hands an existing Cubit to the screen. The test
      // created it, so the test closes it (addTearDown above).
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const GameScreen()),
    ),
  );
  await tester.pumpAndSettle(); // finish the page transition
  return (cubit, clock);
}

/// Moves game time by [time] and draws the result.
///
/// pumpAndSettle, not pump: the Cubit hands new states to BlocBuilder via a
/// stream, which delivers them a moment later (a microtask). A single pump
/// can draw its frame before that, showing the state one step late. It's
/// safe here because the clock is fake: nothing keeps scheduling frames.
Future<void> elapse(WidgetTester tester, FakeClock clock, Duration time) async {
  clock.elapse(time);
  await tester.pumpAndSettle();
}

/// Taps the button labelled [label] and draws the result (see [elapse]).
Future<void> tapLabel(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Presses the system Back button (Android) and draws the result.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
