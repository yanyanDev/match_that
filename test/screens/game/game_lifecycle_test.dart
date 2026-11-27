// Spec §10 step 9 — auto-pause when the app is hidden (§4d L1, L2).
// Written test-first.
//
// Lifecycle changes are simulated through the test binding (see
// test/helpers/lifecycle_helpers.dart); the Game page's real
// AppLifecycleListener receives them, like on a device (L4).

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/screens/game/game_screen.dart';

import '../../helpers/game_helpers.dart';
import '../../helpers/game_screen_helpers.dart';
import '../../helpers/lifecycle_helpers.dart';

void main() {
  group('L1: hidden pauses', () {
    testWidgets('1. during play: paused, the clock stops, the menu shows', (
      tester,
    ) async {
      final (cubit, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(3)); // countdown → play
      await elapse(tester, clock, secs(10)); // 50 s left

      await leaveApp(tester);
      // While paused, phase and phaseRemaining keep what was paused.
      expect(cubit.state.paused, isTrue);
      expect(cubit.state.phase, GamePhase.attempting);
      expect(cubit.state.phaseRemaining, secs(50));

      final whilePaused = cubit.state;
      await elapse(tester, clock, secs(5)); // the clock is stopped (A1)
      expect(cubit.state, same(whilePaused));

      await returnToApp(tester);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
    });

    testWidgets('2a. during the countdown: paused', (tester) async {
      final (cubit, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(1));

      await leaveApp(tester);
      expect(cubit.state.paused, isTrue);
      expect(cubit.state.phase, GamePhase.countdown);
    });

    testWidgets('2b. during the reveal: paused', (tester) async {
      final (cubit, clock) = await pumpGame(tester, config: timed(target: 10));
      await elapse(tester, clock, secs(3));
      await tapLabel(tester, 'MATCHED'); // → reveal

      await leaveApp(tester);
      expect(cubit.state.paused, isTrue);
      expect(cubit.state.phase, GamePhase.reveal);
    });
  });

  testWidgets('3. L1: inactive alone (a brief overlay) does not pause', (
    tester,
  ) async {
    final (cubit, clock) = await pumpGame(tester);
    await elapse(tester, clock, secs(3)); // play, 60 s left

    await showOverlay(tester); // notification shade / Control Center
    expect(cubit.state.paused, isFalse);
    await elapse(tester, clock, secs(1)); // time keeps running
    expect(cubit.state.phaseRemaining, secs(59));

    await returnToApp(tester); // overlay closed
    expect(cubit.state.paused, isFalse);
    expect(cubit.state.phase, GamePhase.attempting);
    expect(find.text('PAUSED'), findsNothing);
  });

  testWidgets('4. L2: returning does not resume; RESUME runs the countdown', (
    tester,
  ) async {
    final (cubit, clock) = await pumpGame(tester);
    await elapse(tester, clock, secs(3));
    await leaveApp(tester);

    await returnToApp(tester);
    expect(cubit.state.paused, isTrue);
    await elapse(tester, clock, secs(5)); // still nothing passes
    expect(cubit.state.paused, isTrue);
    expect(find.text('PAUSED'), findsOneWidget);

    await tapLabel(tester, 'RESUME'); // U2
    expect(cubit.state.paused, isFalse);
    expect(cubit.state.phase, GamePhase.countdown);
    expect(find.text('GET READY'), findsOneWidget);
  });

  testWidgets('5. L2: hidden while already paused changes nothing', (
    tester,
  ) async {
    final (cubit, clock) = await pumpGame(tester);
    await elapse(tester, clock, secs(3));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    final paused = cubit.state;

    await leaveApp(tester);
    await returnToApp(tester);
    expect(cubit.state, same(paused));
  });

  testWidgets('6. L2: hidden on Results changes nothing', (tester) async {
    final (cubit, clock) = await pumpGame(tester, config: timed(target: 1));
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED'); // → gameOver
    final over = cubit.state;

    await leaveApp(tester);
    await returnToApp(tester);
    expect(cubit.state, same(over));
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('PAUSED'), findsNothing);
  });

  testWidgets('7. L2: after leaving the Game page, lifecycle changes are '
      'harmless (the listener is gone)', (tester) async {
    final (_, clock) = await pumpGame(tester, config: timed(target: 1));
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED');
    await pressBack(tester); // Back on Results = New game (D15)
    expect(find.byType(GameScreen), findsNothing);

    await leaveApp(tester);
    await returnToApp(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(belowGame), findsOneWidget);
  });
}
