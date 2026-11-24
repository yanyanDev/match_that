// Spec §10 step 8d — Results logic (§7 D7, D15; §3 S4, S5, S7; §4a G10).
// Written test-first.
//
// Plain `test`s. Game-over states come from real games played with the
// engine helpers (instant config, ZeroRandom: P1 starts, tricks in library
// order) or, for exact scores, from a game-over state with its scores set.

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/turn_based_game.dart';
import 'package:match_that/screens/results/results_display.dart';

import '../../helpers/game_helpers.dart';

/// Pause, then End game (the engine only ends a paused game, U7).
GameState endGame(TurnBasedGame game, GameState s) =>
    game.endGame(game.pause(s));

/// A finished [players]-player game with exactly these [scores] by player
/// id, ended by End game (no sudden death involved).
GameState finishedWith(Map<String, int> scores) {
  final (_, start) = startGame(players: scores.length);
  return start.copyWith(
    scores: scores,
    phase: GamePhase.gameOver,
    endReason: GameEndReason.noDrawableTricks,
  );
}

/// The standings as "rank name score" lines, easy to compare.
List<String> table(GameState s) => [
  for (final row in standings(s))
    '${row.rank} ${row.player.name} ${row.score}'
        '${row.isWinner ? ' W' : ''}${row.wonSuddenDeath ? ' SD' : ''}',
];

void main() {
  group('resultsHeadline (D7)', () {
    test('one winner: P1 WINS!', () {
      final (game, start) = startGame(config: instant(target: 1));
      final over = play(game, start, 'L'); // P1 reaches the target
      expect(over.phase, GamePhase.gameOver);
      expect(resultsHeadline(over), 'P1 WINS!');
    });

    test('sudden-death winner: P1 WINS IN SUDDEN DEATH!', () {
      final (game, tied) = tiedGame(); // 1–1, sudden death, P1 starts
      final over = play(game, tied, 'LM'); // P1 lands, P2 misses: P2 out
      expect(over.endReason, GameEndReason.suddenDeathWon);
      expect(resultsHeadline(over), 'P1 WINS IN SUDDEN DEATH!');
    });

    test('End game during sudden death: P1 & P2 SHARE THE WIN! (S7)', () {
      final (game, tied) = tiedGame();
      final over = endGame(game, tied);
      expect(resultsHeadline(over), 'P1 & P2 SHARE THE WIN!');
    });

    test('three-way shared win: P1, P2 & P3 SHARE THE WIN!', () {
      final (game, tied) = allTied(3);
      final over = endGame(game, tied);
      expect(resultsHeadline(over), 'P1, P2 & P3 SHARE THE WIN!');
    });

    test('a tie on points with no sudden death (nothing drawable, G9)', () {
      final over = finishedWith({'p1': 3, 'p2': 3, 'p3': 1});
      expect(resultsHeadline(over), 'P1 & P2 SHARE THE WIN!');
    });
  });

  group('standings (D15)', () {
    test('sorted by score; tied scores share a rank, the next one skips', () {
      final over = finishedWith({'p1': 3, 'p2': 7, 'p3': 3, 'p4': 1});
      expect(table(over), ['1 P2 7 W', '2 P1 3', '2 P3 3', '4 P4 1']);
    });

    test('tied winners share rank 1', () {
      final over = finishedWith({'p1': 3, 'p2': 3, 'p3': 1});
      expect(table(over), ['1 P1 3 W', '1 P2 3 W', '3 P3 1']);
    });

    test('a sudden-death winner ranks above the player they knocked out, '
        'with equal points (S5)', () {
      final (game, tied) = tiedGame();
      final over = play(game, tied, 'LM');
      expect(over.scores, {'p1': 1, 'p2': 1}); // no points in sudden death
      expect(table(over), ['1 P1 1 W SD', '2 P2 1']);
    });

    test('a shared win in sudden death: both winners rank 1, no SD mark', () {
      final (game, tied) = tiedGame();
      final over = endGame(game, tied);
      expect(table(over), ['1 P1 1 W', '1 P2 1 W']);
    });

    test('players knocked out of a 3-way sudden death share rank 2', () {
      // All three tied at 1; P1 lands, P2 and P3 miss: P1 wins.
      final (game, tied) = allTied(3);
      final over = play(game, tied, 'LMM');
      expect(over.endReason, GameEndReason.suddenDeathWon);
      expect(table(over), ['1 P1 1 W SD', '2 P2 1', '2 P3 1']);
    });
  });

  group('lengthLabel', () {
    test('10 → QUICK PLAY', () => expect(lengthLabel(10), 'QUICK PLAY'));
    test('30 → FULL GAME', () => expect(lengthLabel(30), 'FULL GAME'));
    test('anything else → N TRICKS', () => expect(lengthLabel(5), '5 TRICKS'));
  });
}
