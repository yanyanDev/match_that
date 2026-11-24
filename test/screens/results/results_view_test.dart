// Spec §10 step 8d — Results smoke tests (§7 D7, D10, D15; §4b U3, U6;
// §3 S7, S8). Written test-first.
//
// Results is the Game screen's game-over view, on the same GameCubit, so
// these tests play real games to the end with the Game screen helpers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/screens/game/game_screen.dart';
import 'package:match_that/ui/app_colors.dart';

import '../../helpers/game_helpers.dart';
import '../../helpers/game_screen_helpers.dart';

/// [n] players P1…Pn, each with their own seat color (P3b), so winner rows
/// can be told apart by color.
List<Player> coloredPlayers(int n, {String Function(int seat)? name}) => [
  for (var seat = 0; seat < n; seat++)
    Player(
      id: 'p${seat + 1}',
      seat: seat,
      name: name?.call(seat) ?? 'P${seat + 1}',
      color: PlayerColor.forSeat(seat),
    ),
];

/// The fill of the standings row that shows [name].
Color? rowFill(WidgetTester tester, String name) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(of: find.text(name), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

Future<void> pauseAndEndGame(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Pause'));
  await tester.pumpAndSettle();
  await tapLabel(tester, 'END GAME');
}

void main() {
  testWidgets('1. End game at 1–0: headline, length, standings, winner in '
      'their color, no Undo (U4)', (tester) async {
    final (cubit, clock) = await pumpGame(
      tester,
      config: timed(target: 10),
      players: coloredPlayers(2),
    );
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED'); // P1 1–0
    await elapse(tester, clock, secs(1)); // reveal
    await pauseAndEndGame(tester);

    expect(cubit.state.phase, GamePhase.gameOver);
    expect(find.text('GAME COMPLETE'), findsOneWidget);
    expect(find.text('P1 WINS!'), findsOneWidget);
    expect(find.text('QUICK PLAY'), findsOneWidget);
    expect(find.text('FINAL STANDINGS'), findsOneWidget);
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(find.text('1 PTS'), findsOneWidget);
    expect(find.text('0 PTS'), findsOneWidget);
    expect(rowFill(tester, 'P1'), PlayerColor.color1.color);
    expect(rowFill(tester, 'P2'), isNot(PlayerColor.color2.color));
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('NEW GAME'), findsOneWidget);
    expect(find.text('UNDO LAST CALL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('2. a call ended it: Undo returns to the paused game on the '
      'same Cubit (U3, U6)', (tester) async {
    final (cubit, clock) = await pumpGame(tester, config: timed(target: 1));
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED'); // target 1 reached

    expect(find.text('GAME COMPLETE'), findsOneWidget);
    await tapLabel(tester, 'UNDO LAST CALL');

    expect(cubit.state.phase, GamePhase.attempting);
    expect(cubit.state.paused, isTrue);
    expect(cubit.state.landedCount, 0);
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.text('GAME COMPLETE'), findsNothing);
  });

  testWidgets('3. PLAY AGAIN starts a rematch with the countdown (A2)', (
    tester,
  ) async {
    final (cubit, clock) = await pumpGame(tester, config: timed(target: 1));
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED');

    await tapLabel(tester, 'PLAY AGAIN');
    expect(cubit.state.phase, GamePhase.countdown);
    expect(cubit.state.landedCount, 0);
    expect(find.text('GET READY'), findsOneWidget);
  });

  testWidgets('4a. NEW GAME goes back to the page below: Setup (D14)', (
    tester,
  ) async {
    final (_, clock) = await pumpGame(tester, config: timed(target: 1));
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED');

    await tapLabel(tester, 'NEW GAME');
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text(belowGame), findsOneWidget);
  });

  testWidgets('4b. system Back on Results = New game (D15)', (tester) async {
    final (_, clock) = await pumpGame(tester, config: timed(target: 1));
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED');

    await pressBack(tester);
    expect(find.byType(GameScreen), findsNothing);
    expect(find.text(belowGame), findsOneWidget);
  });

  testWidgets('5. sudden-death win: headline, SUDDEN DEATH mark, winner '
      'ranked first (D15)', (tester) async {
    final (cubit, clock) = await pumpGame(
      tester,
      players: coloredPlayers(2),
    ); // target 2
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED'); // P1 1–0
    await elapse(tester, clock, secs(1));
    await tapLabel(tester, 'MATCHED'); // P2 1–1: sudden death
    await elapse(tester, clock, secs(3)); // its countdown (S2)
    await tapLabel(tester, 'MATCHED'); // P1 lands
    await tapLabel(tester, 'MISSED'); // P2 misses: out

    expect(cubit.state.endReason, GameEndReason.suddenDeathWon);
    expect(find.text('P1 WINS IN SUDDEN DEATH!'), findsOneWidget);
    expect(find.text('SUDDEN DEATH'), findsOneWidget); // P1's row
    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('P1')).dy,
      lessThan(tester.getTopLeft(find.text('P2')).dy),
    );
    expect(rowFill(tester, 'P1'), PlayerColor.color1.color);
  });

  testWidgets('6. End game during sudden death: shared win, both filled, '
      'both rank 01 (S7)', (tester) async {
    final (_, clock) = await pumpGame(tester, players: coloredPlayers(2));
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED');
    await elapse(tester, clock, secs(1));
    await tapLabel(tester, 'MATCHED'); // 1–1: sudden death
    await elapse(tester, clock, secs(3));
    await pauseAndEndGame(tester);

    expect(find.text('P1 & P2 SHARE THE WIN!'), findsOneWidget);
    expect(find.text('01'), findsNWidgets(2));
    expect(find.text('SUDDEN DEATH'), findsNothing);
    expect(rowFill(tester, 'P1'), PlayerColor.color1.color);
    expect(rowFill(tester, 'P2'), PlayerColor.color2.color);
  });

  testWidgets('7. 8 players with 12-character names fit', (tester) async {
    final (_, clock) = await pumpGame(
      tester,
      config: timed(target: 1),
      players: coloredPlayers(8, name: (seat) => 'Long Name 0${seat + 1}'),
    );
    await elapse(tester, clock, secs(3));
    await tapLabel(tester, 'MATCHED');

    expect(find.text('LONG NAME 01 WINS!'), findsOneWidget);
    // The list scrolls if needed; the last player is reachable.
    await tester.scrollUntilVisible(find.text('Long Name 08'), 100);
    expect(find.text('Long Name 08'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
