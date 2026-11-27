// Spec §10 step 9 — the screen stays awake while the Game page is open
// (§4d L3, L4). Written test-first.
//
// A FakeWakelock stands in for the wakelock_plus plugin and records each
// enable/disable. Setup and helpers are in test/helpers/game_screen_helpers.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/screens/game/game_screen.dart';

import '../../helpers/fake_wakelock.dart';
import '../../helpers/game_helpers.dart';
import '../../helpers/game_screen_helpers.dart';

void main() {
  testWidgets('8. opening the Game page keeps the screen awake (L3)', (
    tester,
  ) async {
    final wakelock = FakeWakelock();
    await pumpGame(tester, wakelock: wakelock);

    expect(wakelock.enabled, isTrue);
    expect(wakelock.enables, 1);
    expect(wakelock.disables, 0);
  });

  testWidgets('9. it stays on through countdown, play, reveal, pause menu and '
      'Results (L3)', (tester) async {
    final wakelock = FakeWakelock();
    final (cubit, clock) = await pumpGame(
      tester,
      config: timed(target: 2),
      wakelock: wakelock,
    );

    await elapse(tester, clock, secs(3)); // countdown → play
    await tapLabel(tester, 'MATCHED'); // P1: 1-0 → reveal
    expect(cubit.state.phase, GamePhase.reveal);

    await pressBack(tester); // the reveal has no Pause button; Back pauses (D11)
    expect(cubit.state.paused, isTrue);

    await tapLabel(tester, 'RESUME');
    await elapse(tester, clock, secs(3)); // resume countdown
    await elapse(tester, clock, secs(1)); // rest of the reveal
    await tapLabel(tester, 'MISSED'); // P2 misses, P1's turn
    await tapLabel(tester, 'MATCHED'); // P1: 2-0 → target reached
    expect(cubit.state.phase, GamePhase.gameOver);

    expect(wakelock.enabled, isTrue);
    expect(wakelock.enables, 1); // turned on once, not per view
    expect(wakelock.disables, 0);
  });

  testWidgets('10. leaving the Game page lets the screen sleep (L3)', (
    tester,
  ) async {
    final wakelock = FakeWakelock();
    final (_, clock) = await pumpGame(
      tester,
      config: timed(target: 1),
      wakelock: wakelock,
    );
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED'); // → Results

    await pressBack(tester); // Back on Results = New game (D15)
    expect(find.byType(GameScreen), findsNothing);
    expect(wakelock.enabled, isFalse);
    expect(wakelock.disables, 1);
  });
}
