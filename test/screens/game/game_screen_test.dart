// Spec §10 step 8b — Game screen smoke tests (§7 D10), part 1: countdown,
// play, reveal and sudden death views. Written test-first.
//
// The screen runs on a real GameCubit with a FakeClock: `clock.elapse(...)`
// moves game time instantly, then the screen is redrawn (see elapse).
// ZeroRandom: seat 0 (P1) starts and tricks come out in library order
// (t0, t1, ...), each worth 1 point.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/cubits/game_cubit.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/ui/app_theme.dart';
import 'package:match_that/ui/widgets/primary_button.dart';
import 'package:match_that/ui/widgets/score_card.dart';
import 'package:match_that/ui/widgets/secondary_button.dart';

import '../../helpers/fake_clock.dart';
import '../../helpers/fake_random.dart';
import '../../helpers/game_helpers.dart';

/// Shows a GameScreen for a new game on a phone-sized screen. Returns the
/// Cubit (to check what a tap did) and the clock (to move time).
Future<(GameCubit, FakeClock)> pumpGame(
  WidgetTester tester, {
  GameConfig? config,
  List<Player>? players,
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

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      // BlocProvider.value hands an existing Cubit to the screen. The test
      // created it, so the test closes it (addTearDown above).
      home: BlocProvider.value(value: cubit, child: const GameScreen()),
    ),
  );
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

void main() {
  testWidgets('1. countdown: player and 3, then 2 a second later', (
    tester,
  ) async {
    final (_, clock) = await pumpGame(tester);

    expect(find.text('GET READY'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    await elapse(tester, clock, secs(1));
    expect(find.text('2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2. play: trick, progress, timer and both calls (D4, G3)', (
    tester,
  ) async {
    final (_, clock) = await pumpGame(tester);
    await elapse(tester, clock, secs(3)); // countdown done

    expect(find.text('LANDED 0/2'), findsOneWidget);
    expect(find.text('t0'), findsOneWidget); // trick name only (T5)
    expect(find.text('1 POINT'), findsOneWidget);
    expect(find.text('BEGINNER'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);
    expect(find.text('MISSED'), findsOneWidget);
    expect(find.text('MATCHED'), findsOneWidget);

    await elapse(tester, clock, ms(100)); // 59.9 s
    expect(find.text('60'), findsOneWidget);
    await elapse(tester, clock, ms(1000)); // 58.9 s
    expect(find.text('59'), findsOneWidget);

    // D4: both call buttons at least 72 dp tall, 16 dp apart.
    final missed = tester.getRect(
      find.widgetWithText(SecondaryButton, 'MISSED'),
    );
    final matched = tester.getRect(
      find.widgetWithText(PrimaryButton, 'MATCHED'),
    );
    expect(missed.height, greaterThanOrEqualTo(72));
    expect(matched.height, greaterThanOrEqualTo(72));
    expect(missed.top, matched.top); // side by side
    expect(matched.left - missed.right, 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3a. MATCHED: reveal shows +1 P1, then NEW TRICK for P2', (
    tester,
  ) async {
    final (cubit, clock) = await pumpGame(tester, config: timed(target: 10));
    await elapse(tester, clock, secs(3));

    await tapLabel(tester, 'MATCHED');
    expect(cubit.state.phase, GamePhase.reveal);
    expect(find.text('+1 P1'), findsOneWidget);

    await elapse(tester, clock, ms(500)); // second half of the 1 s reveal
    expect(find.text('NEW TRICK'), findsOneWidget);
    expect(find.text("P2'S TURN"), findsOneWidget);

    await elapse(tester, clock, ms(500)); // reveal over
    expect(find.text('t1'), findsOneWidget);
    expect(find.text('LANDED 1/10'), findsOneWidget);
  });

  testWidgets('3b. MISSED calls missed(): same trick, next player', (
    tester,
  ) async {
    final (cubit, clock) = await pumpGame(tester);
    await elapse(tester, clock, secs(3));

    await tapLabel(tester, 'MISSED');
    expect(cubit.state.missCount, 1);
    expect(cubit.state.currentPlayer.id, 'p2');
    expect(find.text('t0'), findsOneWidget);
  });

  testWidgets('6. sudden death: banner, tied players, no timer (S2, S3)', (
    tester,
  ) async {
    final (cubit, clock) = await pumpGame(tester); // target 2
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED'); // P1: 1-0
    await elapse(tester, clock, secs(1)); // reveal
    await tapLabel(tester, 'MATCHED'); // P2: 1-1, target → tie

    expect(cubit.state.inSuddenDeath, isTrue);
    expect(cubit.state.phase, GamePhase.countdown); // S2
    expect(find.text('SUDDEN DEATH'), findsOneWidget);

    await elapse(tester, clock, secs(3));
    expect(cubit.state.phase, GamePhase.attempting);
    expect(find.text('SUDDEN DEATH'), findsOneWidget);
    expect(find.text('P1'), findsWidgets);
    expect(find.text('P2'), findsWidgets);
    expect(find.text('MATCHED'), findsOneWidget);
    expect(find.text('LANDED 2/2'), findsNothing);
    expect(find.text('60'), findsNothing); // no timer (S3)
    expect(tester.takeException(), isNull);
  });

  testWidgets('7. 8 players with 12-character names fit; active card visible '
      '(D3)', (tester) async {
    final players = [
      for (var seat = 0; seat < 8; seat++)
        Player(
          id: 'p${seat + 1}',
          seat: seat,
          name: 'Long Name 0${seat + 1}', // 12 characters (P3a max)
          color: PlayerColor.forSeat(seat),
        ),
    ];
    final (cubit, clock) = await pumpGame(
      tester,
      config: timed(target: 10),
      players: players,
    );
    await elapse(tester, clock, secs(3));
    expect(tester.takeException(), isNull);

    // Seven misses: P8's turn (miss limit is 16, so the trick stays).
    for (var i = 0; i < 7; i++) {
      await tapLabel(tester, 'MISSED'); // also lets the score row scroll
    }
    expect(cubit.state.currentPlayer.id, 'p8');

    final card = find.descendant(
      of: find.byType(ScoreCard),
      matching: find.text('Long Name 08'),
    );
    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(tester.getRect(card).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(card).right, lessThanOrEqualTo(screenWidth));
    expect(tester.takeException(), isNull);
  });
}
