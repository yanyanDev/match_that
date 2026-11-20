// Spec §10 step 4 — trick lifecycle, Default mode (R1, R5–R8, §4a G1–G11).
// Written test-first. Round 1: countdown and reveal are 0, no ticks.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_that/engine/draw_weights.dart';
import 'package:match_that/engine/game_config.dart';
import 'package:match_that/engine/game_state.dart';
import 'package:match_that/engine/players.dart';
import 'package:match_that/engine/trick.dart';
import 'package:match_that/engine/turn_based_game.dart';

import '../helpers/fake_random.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Trick trick(String id, int points, [Difficulty tier = Difficulty.beginner]) =>
    Trick(
      id: id,
      name: id,
      trick: id,
      stance: Stance.regular,
      modifier: null,
      points: points,
      difficulty: tier,
    );

/// Three beginner tricks worth 3, 5 and 7 points.
final library3 = [trick('b0', 3), trick('b1', 5), trick('b2', 7)];

final onlyBeginner = DrawWeights(beginner: 1, intermediate: 0, advanced: 0);

/// [n] players with ids p1…pN at seats 0…N-1. Built directly (not with
/// `buildPlayers`) so tests can also make invalid counts.
List<Player> makePlayers(int n) => [
  for (var seat = 0; seat < n; seat++)
    Player(
      id: 'p${seat + 1}',
      seat: seat,
      name: 'P${seat + 1}',
      color: PlayerColor.color1,
    ),
];

/// A config with no countdown and no reveal, so no ticks are needed.
GameConfig instant({int target = 10, DrawWeights? weights}) => GameConfig(
  target: target,
  weights: weights ?? onlyBeginner,
  countdown: Duration.zero,
  reveal: Duration.zero,
);

/// The engine plus its starting state. ZeroRandom by default: seat 0 starts
/// and tricks come out in library order.
(TurnBasedGame, GameState) startGame({
  int players = 2,
  List<Trick>? library,
  GameConfig? config,
  Random? random,
}) {
  final game = TurnBasedGame(
    config: config ?? instant(),
    library: library ?? library3,
    random: random ?? ZeroRandom(),
  );
  return (game, game.start(makePlayers(players)));
}

/// Applies [input] [n] times.
GameState times(int n, GameState state, GameState Function(GameState) input) {
  var s = state;
  for (var i = 0; i < n; i++) {
    s = input(s);
  }
  return s;
}

Matcher landedBy(String trickId, String playerId, int points) => isA<LandedBy>()
    .having((o) => o.trick.id, 'trick', trickId)
    .having((o) => o.playerId, 'playerId', playerId)
    .having((o) => o.points, 'points', points);

Matcher missedOut(String trickId) =>
    isA<MissedOut>().having((o) => o.trick.id, 'trick', trickId);

List<String> ids(Iterable<Player> players) => [for (final p in players) p.id];

void main() {
  // -------------------------------------------------------------------------
  // Round 1
  // -------------------------------------------------------------------------

  group('start', () {
    test('random first player, zero scores, first trick drawn, attempting', () {
      // Random: nextInt(4) = seat 2, then nextInt(1) tier, nextInt(3) trick.
      final (_, s) = startGame(players: 4, random: FakeRandom([2, 0, 0]));

      expect(s.phase, GamePhase.attempting); // countdown 0 is skipped
      expect(s.currentPlayer.seat, 2);
      expect(s.upNext.seat, 3);
      expect(s.scores, {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0});
      expect(s.landedCount, 0);
      expect(s.missCount, 0);
      expect(s.currentTrick!.id, 'b0');
      expect(s.phaseRemaining, const Duration(seconds: 60));
      expect(s.lastOutcome, isNull);
      expect(s.endReason, isNull);
    });

    test('throws for a player count outside Default mode limits (P1)', () {
      final game = TurnBasedGame(
        config: instant(),
        library: library3,
        random: ZeroRandom(),
      );
      expect(() => game.start(makePlayers(1)), throwsArgumentError);
      expect(() => game.start(makePlayers(9)), throwsArgumentError);
    });

    test('nothing drawable at start ends the game (G9, T11)', () {
      final (_, s) = startGame(
        config: instant(
          weights: DrawWeights(beginner: 0, intermediate: 0, advanced: 1),
        ),
      );
      expect(s.phase, GamePhase.gameOver);
      expect(s.endReason, GameEndReason.noDrawableTricks);
      expect(s.currentTrick, isNull);
    });
  });

  group('landed (R6, R7, G5)', () {
    test('awards points to the current player and moves to the next trick', () {
      final (game, start) = startGame(players: 3);
      final s = game.landed(start);

      expect(s.scores, {'p1': 3, 'p2': 0, 'p3': 0});
      expect(s.landedCount, 1);
      expect(s.currentPlayer.seat, 1);
      expect(s.currentTrick!.id, 'b1');
      expect(s.missCount, 0);
      expect(s.phase, GamePhase.attempting);
      expect(s.lastOutcome, landedBy('b0', 'p1', 3));
    });

    test(
      'after a miss, the lander scores and the player after them is next',
      () {
        final (game, start) = startGame(players: 3);
        final s = game.landed(game.missed(start)); // p1 misses, p2 lands

        expect(s.scores, {'p1': 0, 'p2': 3, 'p3': 0});
        expect(s.currentPlayer.seat, 2);
        expect(s.missCount, 0);
      },
    );

    test('a landed trick is not discarded and comes back (T11)', () {
      final (game, start) = startGame(library: [trick('only', 4)]);
      final s = game.landed(start);

      expect(s.bags.discardedIds, isEmpty);
      expect(s.currentTrick!.id, 'only');
    });
  });

  group('missed (R1, R5, G6)', () {
    test('a miss advances the turn and keeps the same trick', () {
      final (game, start) = startGame(players: 2);
      final s = game.missed(start);

      expect(s.missCount, 1);
      expect(s.currentPlayer.seat, 1);
      expect(s.currentTrick!.id, 'b0');
      expect(s.scores, {'p1': 0, 'p2': 0});
      expect(s.phase, GamePhase.attempting);
      expect(s.lastOutcome, isNull);
    });

    test('2 players: the 4th miss discards the trick (miss out)', () {
      final (game, start) = startGame(players: 2);

      final three = times(3, start, game.missed);
      expect(three.currentTrick!.id, 'b0');
      expect(three.missCount, 3);
      expect(three.currentPlayer.seat, 1);

      final four = game.missed(three);
      expect(four.currentTrick!.id, 'b1');
      expect(four.missCount, 0);
      expect(four.bags.discardedIds, {'b0'});
      expect(four.lastOutcome, missedOut('b0'));
      expect(four.currentPlayer.seat, 0); // next in order after seat 1 (R7)
      expect(four.phase, GamePhase.attempting);
    });

    test('3 players: the limit is 6 misses, not 4', () {
      final (game, start) = startGame(players: 3);
      expect(start.missLimit, 6);

      final five = times(5, start, game.missed);
      expect(five.currentTrick!.id, 'b0');
      expect(five.missCount, 5);

      final six = game.missed(five);
      expect(six.currentTrick!.id, 'b1');
      expect(six.lastOutcome, missedOut('b0'));
    });

    test(
      'a missed-out trick never comes back, even after reshuffles (T10)',
      () {
        final (game, start) = startGame(
          library: [trick('a', 1), trick('b', 2)],
          config: instant(target: 100),
        );
        var s = times(4, start, game.missed); // miss out 'a'
        for (var i = 0; i < 5; i++) {
          expect(s.currentTrick!.id, 'b');
          s = game.landed(s);
        }
      },
    );

    test('missed-out tricks do not count toward the target (R8)', () {
      final (game, start) = startGame(config: instant(target: 1));
      final s = times(4, start, game.missed);

      expect(s.landedCount, 0);
      expect(s.phase, GamePhase.attempting);
    });
  });

  group('game over (R8, G5, G9)', () {
    test('reaching the target ends the game without a new draw', () {
      final (game, start) = startGame(config: instant(target: 2));
      final one = game.landed(start);
      final over = game.landed(one);

      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.targetReached);
      expect(over.landedCount, 2);
      expect(over.scores, {'p1': 3, 'p2': 5});
      expect(over.lastOutcome, landedBy('b1', 'p2', 5));
      expect(over.bags, same(one.bags)); // nothing drawn
    });

    test('missing out the last drawable trick ends the game', () {
      final (game, start) = startGame(library: [trick('only', 4)]);
      final s = times(4, start, game.missed);

      expect(s.phase, GamePhase.gameOver);
      expect(s.endReason, GameEndReason.noDrawableTricks);
      expect(s.lastOutcome, missedOut('only'));
      expect(s.currentTrick, isNull);
    });
  });

  group('winners (G10)', () {
    test('a single leader wins', () {
      final (game, start) = startGame(players: 3, config: instant(target: 1));
      final over = game.landed(start);
      expect(over.phase, GamePhase.gameOver);
      expect(ids(over.winners), ['p1']);
    });

    test('a tie lists every tied player, in seat order', () {
      // 3 players, seat 2 starts: p3 lands 2, then p1 lands 2.
      final (game, start) = startGame(
        players: 3,
        library: [trick('x', 2), trick('y', 2)],
        config: instant(target: 2),
        random: FakeRandom([2, 0, 0, 0, 0]),
      );
      final over = game.landed(game.landed(start));

      // Step 4 only reports the tie; sudden death is step 6 (G10).
      expect(over.phase, GamePhase.gameOver);
      expect(over.endReason, GameEndReason.targetReached);
      expect(over.scores, {'p1': 2, 'p2': 0, 'p3': 2});
      expect(ids(over.winners), ['p1', 'p3']);
    });

    test('with no points scored, everyone is tied', () {
      final (_, s) = startGame(
        players: 3,
        config: instant(
          weights: DrawWeights(beginner: 0, intermediate: 0, advanced: 1),
        ),
      );
      expect(ids(s.winners), ['p1', 'p2', 'p3']);
    });
  });

  group('immutability (G11)', () {
    test('inputs leave the previous state untouched', () {
      final (game, start) = startGame();
      game.landed(start);
      game.missed(start);

      expect(start.scores, {'p1': 0, 'p2': 0});
      expect(start.landedCount, 0);
      expect(start.missCount, 0);
      expect(start.currentTrick!.id, 'b0');
      expect(start.turnOrder.current, 0);
    });

    test('players and scores are read-only', () {
      final (_, s) = startGame();
      expect(() => s.scores['p1'] = 99, throwsUnsupportedError);
      expect(() => s.players.removeLast(), throwsUnsupportedError);
    });
  });

  group('GameConfig (G1)', () {
    test('rejects invalid values', () {
      GameConfig make({
        int target = 10,
        Duration trickTime = const Duration(seconds: 60),
        Duration countdown = Duration.zero,
        Duration reveal = Duration.zero,
      }) => GameConfig(
        target: target,
        weights: onlyBeginner,
        trickTime: trickTime,
        countdown: countdown,
        reveal: reveal,
      );

      expect(() => make(target: 0), throwsArgumentError);
      expect(() => make(trickTime: Duration.zero), throwsArgumentError);
      expect(
        () => make(countdown: const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(
        () => make(reveal: const Duration(milliseconds: -1)),
        throwsArgumentError,
      );
      expect(make, returnsNormally); // 0 countdown and reveal are allowed
    });

    test('forSetup uses the spec defaults', () {
      expect(GameLength.quickplay.target, 10);
      expect(GameLength.full.target, 30);

      final c = GameConfig.forSetup(Difficulty.intermediate, GameLength.full);
      expect(c.target, 30);
      expect(c.trickTime, const Duration(seconds: 60));
      expect(c.countdown, const Duration(seconds: 3));
      expect(c.reveal, const Duration(seconds: 1));
      expect(
        [c.weights.beginner, c.weights.intermediate, c.weights.advanced],
        [20, 60, 20],
      );
    });
  });
}
