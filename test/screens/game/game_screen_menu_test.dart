// Spec §10 step 8b — Game screen smoke tests (§7 D10), part 2: pause menu
// (R2, U3, U6, U7), Back acts as Pause (D11) and the temporary game-over
// placeholder. Written test-first.
//
// Setup and helpers are in test/helpers/game_screen_helpers.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/ui/widgets/secondary_button.dart';

import '../../helpers/game_helpers.dart';
import '../../helpers/game_screen_helpers.dart';

/// The pause menu's / placeholder's Undo button.
SecondaryButton undoButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(SecondaryButton, 'UNDO LAST CALL'));

Future<void> tapPause(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pause'));
  await tester.pumpAndSettle();
}

void main() {
  group('4. pause menu', () {
    testWidgets('Pause opens the menu over the game; taps below are blocked', (
      tester,
    ) async {
      final (cubit, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(3));

      await tapPause(tester);
      expect(cubit.state.paused, isTrue);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('UNDO LAST CALL'), findsOneWidget);
      expect(find.text('END GAME'), findsOneWidget);

      // The game is still drawn underneath, but the barrier eats the tap.
      await tester.tap(find.text('MATCHED'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(cubit.state.landedCount, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Undo is disabled with no call to undo (U3)', (tester) async {
      final (_, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(3));

      await tapPause(tester);
      expect(undoButton(tester).onPressed, isNull);
    });

    testWidgets('after a call, Undo reverses it and stays paused (U3, U6)', (
      tester,
    ) async {
      final (cubit, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(3));
      await tapLabel(tester, 'MISSED');
      expect(cubit.state.missCount, 1);

      await tapPause(tester);
      expect(undoButton(tester).onPressed, isNotNull);
      await tapLabel(tester, 'UNDO LAST CALL');

      expect(cubit.state.missCount, 0);
      expect(cubit.state.currentPlayer.id, 'p1');
      expect(cubit.state.paused, isTrue);
      expect(find.text('PAUSED'), findsOneWidget);
    });

    testWidgets('Resume closes the menu and runs the countdown (U2)', (
      tester,
    ) async {
      final (cubit, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(3));
      await tapPause(tester);

      await tapLabel(tester, 'RESUME');
      expect(cubit.state.paused, isFalse);
      expect(cubit.state.phase, GamePhase.countdown);
      expect(find.text('PAUSED'), findsNothing);
      expect(find.text('GET READY'), findsOneWidget);
    });

    testWidgets('End game ends it: game over with the winner (R9, U7)', (
      tester,
    ) async {
      final (cubit, clock) = await pumpGame(tester, config: timed(target: 10));
      await elapse(tester, clock, secs(3));
      await tapLabel(tester, 'MATCHED'); // P1 leads 1-0, so no tie
      await elapse(tester, clock, secs(1));

      await tapPause(tester);
      await tapLabel(tester, 'END GAME');
      expect(cubit.state.phase, GamePhase.gameOver);
      expect(find.text('GAME COMPLETE'), findsOneWidget); // Results (8d)
      expect(find.textContaining('P1'), findsWidgets);
    });
  });

  group('5. system Back acts as Pause (D11)', () {
    testWidgets('during play: opens the pause menu, stays in the game', (
      tester,
    ) async {
      final (cubit, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(3));

      await pressBack(tester);
      expect(cubit.state.paused, isTrue);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.byType(GameScreen), findsOneWidget);
    });

    testWidgets('during the countdown too', (tester) async {
      final (cubit, _) = await pumpGame(tester);

      await pressBack(tester);
      expect(cubit.state.paused, isTrue);
      expect(find.byType(GameScreen), findsOneWidget);
    });

    testWidgets('while paused: does nothing', (tester) async {
      final (cubit, clock) = await pumpGame(tester);
      await elapse(tester, clock, secs(3));
      await pressBack(tester);

      await pressBack(tester);
      expect(cubit.state.paused, isTrue);
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.text(belowGame), findsNothing);
    });

    testWidgets('after game over: leaves the screen', (tester) async {
      final (_, clock) = await pumpGame(tester, config: timed(target: 1));
      await elapse(tester, clock, secs(3));
      await tapLabel(tester, 'MATCHED'); // target 1 reached: game over

      await pressBack(tester);
      expect(find.byType(GameScreen), findsNothing);
      expect(find.text(belowGame), findsOneWidget);
    });
  });
}
